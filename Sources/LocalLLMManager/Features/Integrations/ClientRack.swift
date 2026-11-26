import AppKit
import SwiftUI

struct ClientRack: View {
    @ObservedObject var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 185), spacing: LuluTheme.Space.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            LuluSectionHeader("Use on this Mac", symbol: "arrow.up.right")
            if model.phase != .ready {
                Text("Start the server to connect your coding tools.")
                    .font(LuluTheme.TypeStyle.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: LuluTheme.Space.sm) {
                ForEach(ClientID.allCases) { client in
                    let supported = client.supports(engine: model.runningModel?.engineID)
                    Button { model.configure(client) } label: {
                        HStack(spacing: LuluTheme.Space.sm) {
                            ClientIcon(name: client.rawValue)
                            Text(client.title).lineLimit(1)
                            Spacer(minLength: 0)
                            if model.configuringClient == client {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.phase != .ready || !supported || model.configuringClient != nil)
                    .accessibilityLabel("Connect \(client.title)")
                    .help(help(for: client, supported: supported))
                }
            }
        }
        .padding(LuluTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luluCard()
    }

    private func help(for client: ClientID, supported: Bool) -> String {
        if client == .openbot {
            return supported ? "Configure OpenBot Desktop with the active MLX model" : "Automatic OpenBot setup requires MLX"
        }
        return supported ? "Connect \(client.title) to Lulu" : "Requires a compatible llama.cpp server"
    }
}

struct ConfiguredSheet: View {
    let notice: ClientNotice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
            HStack(spacing: LuluTheme.Space.md) {
                ClientIcon(name: notice.client.rawValue)
                VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                    Text("Configured")
                        .font(LuluTheme.TypeStyle.page)
                    Text(notice.client.title)
                        .font(LuluTheme.TypeStyle.body)
                        .foregroundStyle(.secondary)
                }
            }
            Text(notice.detail)
                .font(LuluTheme.TypeStyle.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(LuluTheme.Space.xl)
        .frame(width: 440)
        .background(LuluTheme.canvas)
    }
}

struct ClientIcon: View {
    let name: String

    var body: some View {
        Group {
            if name == ClientID.aider.rawValue {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(LuluTheme.accent)
            } else if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(LuluTheme.TypeStyle.section)
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .accessibilityHidden(true)
    }

    private var image: NSImage? {
        if name == ClientID.openbot.rawValue,
           let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.openbot.desktop") {
            return NSWorkspace.shared.icon(forFile: app.path)
        }
        return NSImage(contentsOf: Self.url(name))
    }

    private static func url(_ name: String) -> URL {
        if let nested = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "clients") {
            return nested
        }
        return Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/clients/\(name).png")
    }
}
