import SwiftUI
import AppKit
import Foundation
import Darwin

// MARK: - Models & Data Structures

struct ModelItem: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String       // "mlx" or "gguf"
    let subtype: String    // "mlx-lm", "mlx-vlm", "llama.cpp"
    let path: String
    let mmproj: String?
    let sizeString: String
}

// MARK: - Engine Manager

class EngineManager: ObservableObject {
    @Published var models: [ModelItem] = []
    @Published var selectedModelId: String = ""
    @Published var contextLength: Int = 4096
    
    @Published var isRunning: Bool = false
    @Published var runningModel: ModelItem? = nil
    @Published var runningPid: pid_t = 0
    
    @Published var modelMemoryBytes: UInt64 = 0
    @Published var systemAvailableBytes: UInt64 = 0
    @Published var systemTotalBytes: UInt64 = 0
    
    @Published var logOutput: String = ""
    @Published var errorMessage: String? = nil
    @Published var copiedAlert: Bool = false
    
    private var timer: Timer?
    private let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local-llm-engine.log")
    
    let contextOptions: [Int] = [2048, 4096, 8192, 16384, 32768, 65536]
    
    init() {
        scanModels()
        updateMemoryStats()
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func scanModels() {
        var found: [ModelItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        // 1. Scan MLX models (~/models/mlx)
        let mlxDir = home.appendingPathComponent("models/mlx")
        if let items = try? FileManager.default.contentsOfDirectory(at: mlxDir, includingPropertiesForKeys: nil) {
            for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    let name = item.lastPathComponent
                    let sz = folderSize(item)
                    let isVLM = name.lowercased().contains("minicpm") || name.lowercased().contains("vision") || name.lowercased().contains("-v-") || name.lowercased().contains("vl")
                    found.append(ModelItem(
                        id: name,
                        name: name,
                        type: "mlx",
                        subtype: isVLM ? "mlx-vlm" : "mlx-lm",
                        path: item.path,
                        mmproj: nil,
                        sizeString: formatBytes(sz)
                    ))
                }
            }
        }
        
        // 2. Scan GGUF models (~/models/gguf)
        let ggufDir = home.appendingPathComponent("models/gguf")
        if let enumerator = FileManager.default.enumerator(at: ggufDir, includingPropertiesForKeys: [.fileSizeKey]) {
            var filesByDir: [String: [URL]] = [:]
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "gguf" {
                    let parent = fileURL.deletingLastPathComponent().path
                    filesByDir[parent, default: []].append(fileURL)
                }
            }
            
            for (_, urls) in filesByDir {
                for u in urls {
                    let fname = u.lastPathComponent
                    if !fname.hasPrefix("mmproj") {
                        let mmprojURL = urls.first(where: { $0.lastPathComponent.hasPrefix("mmproj") })
                        let sz = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                        found.append(ModelItem(
                            id: fname.replacingOccurrences(of: ".gguf", with: ""),
                            name: fname.replacingOccurrences(of: ".gguf", with: ""),
                            type: "gguf",
                            subtype: "llama.cpp",
                            path: u.path,
                            mmproj: mmprojURL?.path,
                            sizeString: formatBytes(UInt64(sz))
                        ))
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.models = found
            if self.selectedModelId.isEmpty, let first = found.first {
                self.selectedModelId = first.id
            }
        }
    }
    
    func startEngine() {
        guard let model = models.first(where: { $0.id == selectedModelId }) else { return }
        stopEngine()
        
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let mlxLMBin = "\(home)/.local/bin/mlx_lm.server"
        let mlxVLMBin = "\(home)/.local/bin/mlx_vlm.server"
        let llamaBin = "/opt/homebrew/bin/llama-server"
        
        var binPath = ""
        var args: [String] = []
        
        if model.type == "mlx" {
            binPath = model.subtype == "mlx-vlm" ? mlxVLMBin : mlxLMBin
            args = ["--model", model.path, "--port", "8000", "--max-tokens", String(contextLength)]
        } else {
            binPath = llamaBin
            args = ["-m", model.path, "--port", "8000", "-ngl", "99", "-c", String(contextLength)]
            if let mm = model.mmproj {
                args.append(contentsOf: ["--mmproj", mm])
            }
        }
        
        FileManager.default.createFile(atPath: logPath.path, contents: nil)
        guard let logHandle = try? FileHandle(forWritingTo: logPath) else { return }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binPath)
        proc.arguments = args
        proc.standardOutput = logHandle
        proc.standardError = logHandle
        
        do {
            try proc.run()
            self.runningPid = proc.processIdentifier
            self.runningModel = model
            self.isRunning = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Erro ao iniciar: \(error.localizedDescription)"
        }
    }
    
    func stopEngine() {
        if runningPid > 0 {
            kill(runningPid, SIGTERM)
            usleep(200000)
            kill(runningPid, SIGKILL)
        }
        // Force cleanup any remaining process listening on port 8000
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-c", "lsof -ti:8000 | xargs kill -9 2>/dev/null"]
        try? p.run()
        p.waitUntilExit()
        
        DispatchQueue.main.async {
            self.isRunning = false
            self.runningPid = 0
            self.runningModel = nil
            self.modelMemoryBytes = 0
        }
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryStats()
            self?.checkEngineHealth()
            self?.updateLogs()
        }
    }
    
    private func checkEngineHealth() {
        guard isRunning, runningPid > 0 else { return }
        if kill(runningPid, 0) != 0 {
            // Process terminated
            DispatchQueue.main.async {
                self.isRunning = false
                self.runningPid = 0
                self.runningModel = nil
                self.modelMemoryBytes = 0
            }
        }
    }
    
    private func updateMemoryStats() {
        // Total physical memory
        var total: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &len, nil, 0)
        
        // Available memory from Mach VM
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let pageSize = UInt64(vm_kernel_page_size)
        let available = (UInt64(vmStats.free_count) + UInt64(vmStats.inactive_count)) * pageSize
        
        // Model process RSS memory (Weights + KV Cache + Activations)
        var pMem: UInt64 = 0
        if isRunning && runningPid > 0 {
            var info = proc_taskallinfo()
            let size = proc_pidinfo(runningPid, PROC_PIDTASKALLINFO, 0, &info, Int32(MemoryLayout<proc_taskallinfo>.size))
            if size == MemoryLayout<proc_taskallinfo>.size {
                pMem = info.ptinfo.pti_resident_size
            }
        }
        
        DispatchQueue.main.async {
            self.systemTotalBytes = total
            self.systemAvailableBytes = available
            self.modelMemoryBytes = pMem
        }
    }
    
    private func updateLogs() {
        guard let data = try? Data(contentsOf: logPath),
              let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.components(separatedBy: .newlines)
        let tail = lines.suffix(15).joined(separator: "\n")
        DispatchQueue.main.async {
            self.logOutput = tail
        }
    }
    
    private func folderSize(_ url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let sz = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
                total += UInt64(sz)
            }
        }
        return total
    }
    
    func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        }
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}

// MARK: - SwiftUI Views

struct ContentView: View {
    @ObservedObject var engine: EngineManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local LLM Manager")
                        .font(.system(size: 20, weight: .bold))
                    Text("Apple Silicon • Memória Unificada")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Status Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(engine.isRunning ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                        .shadow(color: engine.isRunning ? Color.green.opacity(0.8) : Color.clear, radius: 4)
                    Text(engine.isRunning ? "Ativo" : "Parado")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            
            Divider()
            
            // Memory & Diagnostics Card
            VStack(alignment: .leading, spacing: 10) {
                Text("DIAGNÓSTICO DE MEMÓRIA")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Modelo + KV Cache")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(engine.formatBytes(engine.modelMemoryBytes))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(engine.isRunning ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("RAM Disponível")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(engine.formatBytes(engine.systemAvailableBytes))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                
                // Visual Memory Bar
                GeometryReader { geo in
                    let total = Double(max(engine.systemTotalBytes, 1))
                    let modelRatio = Double(engine.modelMemoryBytes) / total
                    let usedSysRatio = max(0, 1.0 - (Double(engine.systemAvailableBytes) / total) - modelRatio)
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        HStack(spacing: 0) {
                            if modelRatio > 0 {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green)
                                    .frame(width: geo.size.width * CGFloat(modelRatio), height: 12)
                            }
                            if usedSysRatio > 0 {
                                RoundedRectangle(cornerRadius: modelRatio > 0 ? 0 : 6)
                                    .fill(Color.blue.opacity(0.4))
                                    .frame(width: geo.size.width * CGFloat(usedSysRatio), height: 12)
                            }
                        }
                    }
                }
                .frame(height: 12)
                
                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Modelo & KV Cache").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue.opacity(0.4)).frame(width: 6, height: 6)
                        Text("Sistema/Apps").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Total: \(engine.formatBytes(engine.systemTotalBytes))").font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // Engine Configuration Card
            VStack(alignment: .leading, spacing: 14) {
                Text("CONFIGURAÇÃO DO MOTOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                // Model Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Modelo Local:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $engine.selectedModelId) {
                        ForEach(engine.models) { m in
                            Text("\(m.name) [\(m.subtype.uppercased()) • \(m.sizeString)]")
                                .tag(m.id)
                        }
                    }
                    .labelsHidden()
                    .disabled(engine.isRunning)
                }
                
                // Context Size Picker
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tamanho do Contexto:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(engine.contextLength) tokens")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Picker("", selection: $engine.contextLength) {
                        ForEach(engine.contextOptions, id: \.self) { c in
                            Text("\(c) tokens").tag(c)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(engine.isRunning)
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    if !engine.isRunning {
                        Button(action: {
                            engine.startEngine()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Subir Motor")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        Button(action: {
                            engine.stopEngine()
                        }) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Derrubar Motor (Desligar)")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // API Info Pill
            if engine.isRunning {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("API OpenAI Local:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("http://localhost:8000/v1")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    Spacer()
                    Button(engine.copiedAlert ? "Copiado!" : "Copiar") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("http://localhost:8000/v1", forType: .string)
                        engine.copiedAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            engine.copiedAlert = false
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(10)
                .padding(.horizontal, 20)
            }
            
            // Logs Section
            VStack(alignment: .leading, spacing: 6) {
                Text("SAÍDA / LOGS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                ScrollView {
                    Text(engine.logOutput.isEmpty ? "Aguardando logs do motor..." : engine.logOutput)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 70)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 480)
    }
}

@main
struct LocalLLMManagerApp: App {
    @StateObject private var engine = EngineManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
        }
        .windowResizability(.contentSize)
    }
}
