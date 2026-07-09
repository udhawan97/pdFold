import XCTest
@testable import Orifold

/// Serves canned responses to both the checksum-sidecar data task and the DMG download
/// task, in FIFO order. Shared static state, reset per test.
final class DownloaderStubURLProtocol: URLProtocol {
    struct Response { var status: Int; var headers: [String: String]; var body: Data }
    static let lock = NSLock()
    nonisolated(unsafe) static var responses: [Response] = []

    static func reset() { lock.lock(); responses = []; lock.unlock() }
    static func enqueue(_ r: Response) { lock.lock(); responses.append(r); lock.unlock() }
    static func pop() -> Response? { lock.lock(); defer { lock.unlock() }; return responses.isEmpty ? nil : responses.removeFirst() }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        guard let stub = DownloaderStubURLProtocol.pop() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        var headers = stub.headers
        headers["Content-Length"] = String(stub.body.count)
        let response = HTTPURLResponse(url: request.url!, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class UpdateDownloaderTests: XCTestCase {
    private var session: URLSession!
    private var cacheDir: URL!

    override func setUpWithError() throws {
        DownloaderStubURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DownloaderStubURLProtocol.self]
        session = URLSession(configuration: config)
        cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("orifold-dl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        DownloaderStubURLProtocol.reset()
        try? FileManager.default.removeItem(at: cacheDir)
    }

    private func sha256(of data: Data) throws -> String {
        let tmp = cacheDir.appendingPathComponent("hash-\(UUID().uuidString)")
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try RollbackArchiver.sha256(of: tmp)
    }

    private func update(dmg: String? = "https://example.com/Orifold-0.9.0-macOS-universal.dmg") -> AvailableUpdate {
        AvailableUpdate(version: "0.9.0", currentVersion: "0.8.5", releaseNotesURL: nil, downloadPageURL: nil,
                        publishedAt: nil, assetSizeBytes: nil, dmgDownloadURL: dmg.flatMap(URL.init(string:)))
    }

    private func downloader() -> UpdateDownloader {
        UpdateDownloader(session: session, cacheDirectory: cacheDir)
    }

    func testDownloadsAndVerifiesMatchingChecksum() async throws {
        let dmgBytes = Data("PRETEND-DMG-CONTENTS".utf8)
        let hash = try sha256(of: dmgBytes)
        // Sidecar first (data task), then DMG (download task).
        DownloaderStubURLProtocol.enqueue(.init(status: 200, headers: [:], body: Data("\(hash)  Orifold-0.9.0-macOS-universal.dmg".utf8)))
        DownloaderStubURLProtocol.enqueue(.init(status: 200, headers: [:], body: dmgBytes))

        var lastProgress = 0.0
        let url = try await downloader().download(update()) { lastProgress = $0 }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), dmgBytes)
        XCTAssertEqual(url.lastPathComponent, "Orifold-0.9.0.dmg")
        XCTAssertEqual(lastProgress, 1.0, accuracy: 0.001)
    }

    func testRejectsAndDeletesOnChecksumMismatch() async throws {
        let dmgBytes = Data("TAMPERED".utf8)
        let wrongHash = String(repeating: "a", count: 64)
        DownloaderStubURLProtocol.enqueue(.init(status: 200, headers: [:], body: Data("\(wrongHash)  x.dmg".utf8)))
        DownloaderStubURLProtocol.enqueue(.init(status: 200, headers: [:], body: dmgBytes))

        do {
            _ = try await downloader().download(update())
            XCTFail("expected checksum mismatch")
        } catch let UpdateDownloader.DownloadError.checksumMismatch(expected, _) {
            XCTAssertEqual(expected, wrongHash)
        }
        // No verified artifact left behind.
        let leftovers = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "dmg" }
        XCTAssertTrue(leftovers.isEmpty, "a mismatched download must not be left in the cache")
    }

    func testThrowsWhenChecksumSidecarUnavailable() async {
        DownloaderStubURLProtocol.enqueue(.init(status: 404, headers: [:], body: Data()))
        do {
            _ = try await downloader().download(update())
            XCTFail("expected checksumUnavailable")
        } catch {
            XCTAssertEqual(error as? UpdateDownloader.DownloadError, .checksumUnavailable)
        }
    }

    func testThrowsWhenNoDownloadURL() async {
        do {
            _ = try await downloader().download(update(dmg: nil))
            XCTFail("expected noDownloadURL")
        } catch {
            XCTAssertEqual(error as? UpdateDownloader.DownloadError, .noDownloadURL)
        }
    }

    func testRejectsMalformedChecksumSidecar() async {
        DownloaderStubURLProtocol.enqueue(.init(status: 200, headers: [:], body: Data("not-a-valid-hash line".utf8)))
        do {
            _ = try await downloader().download(update())
            XCTFail("expected checksumUnavailable for malformed sidecar")
        } catch {
            XCTAssertEqual(error as? UpdateDownloader.DownloadError, .checksumUnavailable)
        }
    }
}
