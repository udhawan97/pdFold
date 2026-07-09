import XCTest
@testable import Orifold

private struct OrchTransport: UpdateTransport {
    var outcome: UpdateCheckOutcome
    func checkForUpdate(currentVersion: UpdateVersion) async throws -> UpdateCheckOutcome { outcome }
}

private struct OrchDownloader: UpdateDownloading {
    var result: Result<URL, Error>
    func download(_ update: AvailableUpdate, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try result.get()
    }
}

@MainActor
private final class SpyHandOff: UpdateInstallHandOff {
    var launchedInputs: UpdaterScriptGenerator.Inputs?
    var terminated = false
    var launchResult = true
    func launchUpdater(_ inputs: UpdaterScriptGenerator.Inputs) -> Bool {
        launchedInputs = inputs
        return launchResult
    }
    func terminateForInstall() { terminated = true }
}

@MainActor
final class UpdateInstallOrchestrationTests: XCTestCase {
    private var tmp: URL!
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUpWithError() throws {
        suite = "orifold-orch-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: tmp)
    }

    private func update() -> AvailableUpdate {
        AvailableUpdate(version: "0.9.0", currentVersion: "0.8.6", releaseNotesURL: nil, downloadPageURL: nil,
                        publishedAt: nil, assetSizeBytes: nil, dmgDownloadURL: URL(string: "https://example.com/u.dmg"))
    }

    /// Builds a controller already advanced to `.readyToInstall` with a real on-disk DMG and
    /// a fake current bundle to archive.
    private func readyController(spy: SpyHandOff, history: UpdateHistoryStore, markers: UpdateInstallMarkerStore) async throws -> (UpdateController, dmg: URL, bundle: URL) {
        let dmg = tmp.appendingPathComponent("Orifold-0.9.0.dmg")
        try Data("pretend-dmg-bytes".utf8).write(to: dmg)

        let bundle = tmp.appendingPathComponent("Orifold.app")
        try FileManager.default.createDirectory(at: bundle.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try Data("v0.8.6".utf8).write(to: bundle.appendingPathComponent("Contents/marker"))

        let c = UpdateController(
            transport: OrchTransport(outcome: .available(update())),
            downloader: OrchDownloader(result: .success(dmg)),
            defaults: defaults,
            currentVersion: UpdateVersion(string: "0.8.6")!,
            currentBuild: "12",
            archiver: RollbackArchiver(directory: tmp.appendingPathComponent("Rollback")),
            history: history,
            markers: markers,
            handOff: spy,
            bundleURL: bundle,
            processID: 4242,
            now: { Date(timeIntervalSince1970: 100) }
        )
        await c.checkForUpdates(userInitiated: true)
        await c.downloadUpdate()
        guard case .readyToInstall = c.phase else { throw XCTSkip("setup failed to reach readyToInstall: \(c.phase)") }
        return (c, dmg, bundle)
    }

    func testInstallAndRelaunchDrivesTheFullSequenceInOrder() async throws {
        let spy = SpyHandOff()
        let history = UpdateHistoryStore(directory: tmp)
        let markers = UpdateInstallMarkerStore(directory: tmp)
        let (c, dmg, bundle) = try await readyController(spy: spy, history: history, markers: markers)

        let ok = await c.installAndRelaunch(reopenDocuments: [
            ReopenDocument(path: "/Users/x/A.pdf", bookmarkData: nil, pageIndex: 3, displayName: "A"),
        ])

        XCTAssertTrue(ok)
        XCTAssertEqual(c.phase, .installing(update()))
        XCTAssertTrue(spy.terminated, "must quit so the updater can swap the bundle")

        // Hand-off inputs are correct and consistent with the recorded attempt.
        let inputs = try XCTUnwrap(spy.launchedInputs)
        XCTAssertEqual(inputs.appPID, 4242)
        XCTAssertEqual(inputs.newVersion, "0.9.0")
        XCTAssertEqual(inputs.appBundlePath, bundle.path)
        XCTAssertEqual(inputs.dmgPath, dmg.path)
        XCTAssertEqual(inputs.dmgSHA256.count, 64)
        XCTAssertNotNil(inputs.rollbackZipPath, "current bundle should have been archived for rollback")

        // Reopen manifest preserved the on-screen state.
        let reopen = try XCTUnwrap(markers.readReopenManifest())
        XCTAssertEqual(reopen.toVersion, "0.9.0")
        XCTAssertEqual(reopen.documents.first?.pageIndex, 3)

        // Attempt marker matches the hand-off, so the next launch can judge the outcome.
        let attempt = try XCTUnwrap(markers.readAttempt())
        XCTAssertEqual(attempt.toVersion, "0.9.0")
        XCTAssertEqual(attempt.dmgSHA256, inputs.dmgSHA256)

        // History recorded as not-yet-verified.
        XCTAssertEqual(history.latest?.toVersion, "0.9.0")
        XCTAssertEqual(history.latest?.launchVerified, false)
    }

    func testInstallFallsBackToFailedWhenUpdaterWontLaunch() async throws {
        let spy = SpyHandOff()
        spy.launchResult = false
        let history = UpdateHistoryStore(directory: tmp)
        let markers = UpdateInstallMarkerStore(directory: tmp)
        let (c, _, _) = try await readyController(spy: spy, history: history, markers: markers)

        let ok = await c.installAndRelaunch(reopenDocuments: [])
        XCTAssertFalse(ok)
        XCTAssertFalse(spy.terminated, "never quit the app if the updater didn't launch")
        guard case let .failed(failure) = c.phase else { return XCTFail("expected failed, got \(c.phase)") }
        XCTAssertEqual(failure.kind, .install)
        XCTAssertNil(markers.readAttempt(), "a non-started install must not leave an attempt marker")
    }

    func testInstallIsNoOpWhenNotReady() async {
        let spy = SpyHandOff()
        let c = UpdateController(
            transport: OrchTransport(outcome: .upToDate),
            downloader: OrchDownloader(result: .failure(URLError(.badURL))),
            defaults: defaults,
            currentVersion: UpdateVersion(string: "0.8.6")!,
            handOff: spy,
            now: { Date(timeIntervalSince1970: 1) }
        )
        let ok = await c.installAndRelaunch(reopenDocuments: [])
        XCTAssertFalse(ok)
        XCTAssertFalse(spy.terminated)
    }
}
