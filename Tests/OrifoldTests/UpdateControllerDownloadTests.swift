import XCTest
@testable import Orifold

private struct StubTransport: UpdateTransport {
    var outcome: UpdateCheckOutcome
    func checkForUpdate(currentVersion: UpdateVersion) async throws -> UpdateCheckOutcome { outcome }
}

private struct StubDownloader: UpdateDownloading {
    var result: Result<URL, Error>
    func download(_ update: AvailableUpdate, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        progress(0.5)
        progress(1.0)
        return try result.get()
    }
}

@MainActor
final class UpdateControllerDownloadTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var rollbackDir: URL!

    override func setUpWithError() throws {
        suite = "orifold-dl-ctl-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        rollbackDir = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: rollbackDir)
    }

    private func availableUpdate() -> AvailableUpdate {
        AvailableUpdate(version: "0.9.0", currentVersion: "0.8.5", releaseNotesURL: nil, downloadPageURL: nil,
                        publishedAt: nil, assetSizeBytes: nil, dmgDownloadURL: URL(string: "https://example.com/u.dmg"))
    }

    private func controller(download: Result<URL, Error>) -> UpdateController {
        UpdateController(
            transport: StubTransport(outcome: .available(availableUpdate())),
            downloader: StubDownloader(result: download),
            defaults: defaults,
            currentVersion: UpdateVersion(string: "0.8.5")!,
            archiver: RollbackArchiver(directory: rollbackDir),
            now: { Date(timeIntervalSince1970: 1) }
        )
    }

    func testDownloadSuccessLeadsToReadyToInstall() async {
        let dest = rollbackDir.appendingPathComponent("Orifold-0.9.0.dmg")
        let c = controller(download: .success(dest))
        await c.checkForUpdates(userInitiated: true)
        XCTAssertEqual(c.phase.availableUpdate?.version, "0.9.0")

        await c.downloadUpdate()

        guard case let .readyToInstall(update) = c.phase else { return XCTFail("expected readyToInstall, got \(c.phase)") }
        XCTAssertEqual(update.version, "0.9.0")
        XCTAssertEqual(c.downloadedUpdateURL, dest)
    }

    func testChecksumFailureSurfacesAsVerificationFailure() async {
        let c = controller(download: .failure(UpdateDownloader.DownloadError.checksumMismatch(expected: "a", actual: "b")))
        await c.checkForUpdates(userInitiated: true)
        await c.downloadUpdate()

        guard case let .failed(failure) = c.phase else { return XCTFail("expected failed, got \(c.phase)") }
        XCTAssertEqual(failure.kind, .verification, "a checksum mismatch must read as a verification failure")
        XCTAssertNil(c.downloadedUpdateURL)
    }

    func testGenericDownloadErrorSurfacesAsDownloadFailure() async {
        let c = controller(download: .failure(URLError(.timedOut)))
        await c.checkForUpdates(userInitiated: true)
        await c.downloadUpdate()
        guard case let .failed(failure) = c.phase else { return XCTFail("expected failed") }
        XCTAssertEqual(failure.kind, .download)
    }

    func testDownloadIsNoOpWhenNoUpdateIsAvailable() async {
        let c = controller(download: .success(rollbackDir))
        // Never checked → idle. Download should do nothing.
        await c.downloadUpdate()
        XCTAssertEqual(c.phase, .idle)
        XCTAssertNil(c.downloadedUpdateURL)
    }

    func testInstallLaterReturnsToIdleFromReady() async {
        let dest = rollbackDir.appendingPathComponent("Orifold-0.9.0.dmg")
        let c = controller(download: .success(dest))
        await c.checkForUpdates(userInitiated: true)
        await c.downloadUpdate()
        c.installLater()
        XCTAssertEqual(c.phase, .idle)
    }

    func testRevealReturnsFalseWithoutAVerifiedDownload() {
        let c = controller(download: .success(rollbackDir))
        XCTAssertFalse(c.revealDownloadedUpdateForInstall(), "nothing to install without a completed download")
    }
}
