#if canImport(Sparkle)
import AppKit
import Foundation
import Sparkle

/// The install button is the user's consent: subsequent Sparkle stages advance
/// automatically, while progress and errors remain visible in the app.
@MainActor
final class SparkleUpdates: NSObject, ObservableObject, SPUUserDriver {
    static let shared = SparkleUpdates()
    @Published var status: String?
    @Published var busy = false
    private var expectedBytes: UInt64 = 0
    private var receivedBytes: UInt64 = 0
    private var updater: SPUUpdater!

    private override init() {
        super.init()
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: nil)
        do { try updater.start() } catch { status = error.localizedDescription }
    }

    func checkForUpdates() {
        guard !busy else { return }
        busy = true
        status = "Checking the signed update…"
        updater.checkForUpdates()
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { status = "Checking the signed update…" }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard state.userInitiated else { busy = false; reply(.dismiss); return }
        guard !appcastItem.isInformationOnlyUpdate else { status = "This update requires additional information."; busy = false; reply(.dismiss); return }
        status = "Downloading update…"
        reply(.install)
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        status = "No update is available."; busy = false; acknowledgement()
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        status = error.localizedDescription; busy = false; acknowledgement()
    }
    func showDownloadInitiated(cancellation: @escaping () -> Void) { expectedBytes = 0; receivedBytes = 0; status = "Downloading update…" }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) { expectedBytes = expectedContentLength }
    func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedBytes += length
        if expectedBytes > 0 { status = "Downloading update… \(min(100, Int(Double(receivedBytes) / Double(expectedBytes) * 100)))%" }
    }
    func showDownloadDidStartExtractingUpdate() { status = "Verifying and preparing update…" }
    func showExtractionReceivedProgress(_ progress: Double) { status = "Preparing update… \(Int(progress * 100))%" }
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { status = "Installing and restarting…"; reply(.install) }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) { status = "Installing and restarting…" }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { status = "Update installed."; busy = false; acknowledgement() }
    func dismissUpdateInstallation() { busy = false }
}
#endif
