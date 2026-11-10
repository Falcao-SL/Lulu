import AppKit
import SwiftUI

struct ClientRack: View {
    @ObservedObject var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: LuluTheme.Space.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            LuluSectionHeader("Use on this Mac", symbol: "arrow.up.right")
            Text("Each icon configures that application to use the local server.")
                .font(LuluTheme.TypeStyle.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, alignment: .leading, spacing: LuluTheme.Space.sm) {
                ForEach(ClientID.allCases) { client in
                    Button { model.configure(client) } label: {
                        VStack(spacing: LuluTheme.Space.xs) {
                            ClientIcon(name: client.rawValue)
                            Text(client.title)
                                .font(LuluTheme.TypeStyle.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 78)
                        .padding(.vertical, LuluTheme.Space.sm)
                        .background(LuluTheme.subtle, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.models.isEmpty && model.runningModel == nil)
                    .accessibilityLabel("Configure in \(client.title)")
                }
            }
        }
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
            if let image = NSImage(contentsOf: Self.url(name)) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(LuluTheme.TypeStyle.section)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    private static func url(_ name: String) -> URL {
        if let nested = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "clients") {
            return nested
        }
        return Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/clients/\(name).png")
    }
}
