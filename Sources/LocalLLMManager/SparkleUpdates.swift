#if canImport(Sparkle)
import Foundation
import Sparkle

@MainActor
final class SparkleUpdates {
    static let shared = SparkleUpdates()
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#endif
