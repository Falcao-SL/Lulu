import AppKit
import Foundation

struct LuluRelease: Decodable {
    let tag_name: String
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }
}

enum AppUpdates {
    static let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private static let endpoint = URL(string: "https://api.github.com/repos/Falcao-SL/Lulu/releases/latest")!

    static func latest() async throws -> (version: String, download: URL)? {
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let release = try JSONDecoder().decode(LuluRelease.self, from: data)
        let version = String(release.tag_name.drop(while: { $0 == "v" }))
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !release.draft, !release.prerelease, components.count == 3,
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              version.compare(current, options: .numeric) == .orderedDescending else { return nil }
        #if arch(arm64)
        let name = "Lulu-macos-arm64.dmg"
        #else
        let name = "Lulu-macos-x86_64.dmg"
        #endif
        let expectedPath = "/Falcao-SL/Lulu/releases/download/\(release.tag_name)/\(name)"
        guard let url = release.assets.first(where: { $0.name == name })?.browser_download_url,
              url.scheme == "https", url.host == "github.com", url.path == expectedPath else {
            throw URLError(.badServerResponse)
        }
        return (version, url)
    }
}
