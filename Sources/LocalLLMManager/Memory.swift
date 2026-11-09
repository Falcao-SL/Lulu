import Darwin
import Foundation

struct ProcessUsage {
    var footprint: UInt64 = 0
    var resident: UInt64 = 0
    var wired: UInt64 = 0
}

struct SystemMemory {
    var total: UInt64 = 0
    var free: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var purgeable: UInt64 = 0
    var available: UInt64 = 0
}

enum MemoryMonitor {
    static func system() -> SystemMemory {
        var total: UInt64 = 0
        var length = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &length, nil, 0)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return SystemMemory(total: total)
        }
        let page = UInt64(vm_kernel_page_size)
        let free = UInt64(stats.free_count) * page
        let inactive = UInt64(stats.inactive_count) * page
        let speculative = UInt64(stats.speculative_count) * page
        return SystemMemory(
            total: total,
            free: free,
            active: UInt64(stats.active_count) * page,
            inactive: inactive,
            wired: UInt64(stats.wire_count) * page,
            compressed: UInt64(stats.compressor_page_count) * page,
            purgeable: UInt64(stats.purgeable_count) * page,
            available: free + inactive + speculative
        )
    }

    static func tree(of root: pid_t) -> ProcessUsage {
        var seen = Set<pid_t>()
        var pending = [root]
        var usage = ProcessUsage()
        while let pid = pending.popLast() {
            guard seen.insert(pid).inserted else { continue }
            if let one = process(pid) {
                usage.footprint += one.footprint
                usage.resident += one.resident
                usage.wired += one.wired
            }
            pending.append(contentsOf: children(of: pid))
        }
        return usage
    }

    static func terminate(_ root: pid_t) {
        guard root > 0 else { return }
        signalTree(root, SIGTERM)
        usleep(300_000)
        if kill(root, 0) == 0 {
            signalTree(root, SIGKILL)
        }
    }

    static func signalTree(_ root: pid_t, _ signal: Int32) {
        for child in children(of: root) {
            signalTree(child, signal)
        }
        if root > 0 {
            kill(root, signal)
        }
    }

    private static func process(_ pid: pid_t) -> ProcessUsage? {
        var info = RUsageV4()
        let status = withUnsafeMutablePointer(to: &info) {
            proc_pid_rusage(pid, 4, UnsafeMutableRawPointer($0))
        }
        guard status == 0 else { return nil }
        return ProcessUsage(footprint: info.footprint, resident: info.resident, wired: info.wired)
    }

    private static func children(of pid: pid_t) -> [pid_t] {
        var buffer = [Int32](repeating: 0, count: 256)
        let bytes = buffer.count * MemoryLayout<Int32>.size
        let count = buffer.withUnsafeMutableBufferPointer { raw -> Int32 in
            guard let base = raw.baseAddress else { return 0 }
            return proc_listchildpids(pid, UnsafeMutableRawPointer(base), Int32(bytes))
        }
        guard count > 0 else { return [] }
        let limit = min(Int(count), buffer.count)
        return buffer.prefix(limit).filter { $0 > 0 }
    }
}

private struct RUsageV4 {
    var uuid: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    var userTime: UInt64 = 0
    var systemTime: UInt64 = 0
    var pkgIdle: UInt64 = 0
    var interrupt: UInt64 = 0
    var pageins: UInt64 = 0
    var wired: UInt64 = 0
    var resident: UInt64 = 0
    var footprint: UInt64 = 0
    var start: UInt64 = 0
    var exit: UInt64 = 0
    var childUser: UInt64 = 0
    var childSystem: UInt64 = 0
    var childPkg: UInt64 = 0
    var childInterrupt: UInt64 = 0
    var childPageins: UInt64 = 0
    var diskRead: UInt64 = 0
    var diskWrite: UInt64 = 0
}

@_silgen_name("proc_pid_rusage")
private func proc_pid_rusage(_ pid: Int32, _ flavor: Int32, _ buffer: UnsafeMutableRawPointer) -> Int32

@_silgen_name("proc_listchildpids")
private func proc_listchildpids(_ ppid: Int32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32
