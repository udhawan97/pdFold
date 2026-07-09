import XCTest
@testable import Orifold

/// Stubs the network so `GitHubReleaseTransport` can be exercised without hitting GitHub.
/// Each request is answered from a script of canned `(status, headers, body)` responses,
/// and the request that arrived is recorded so tests can assert on `If-None-Match`.
private final class StubURLProtocol: URLProtocol {
    struct Response {
        var status: Int
        var headers: [String: String]
        var body: Data
    }

    /// FIFO queue of responses; each request pops the next one.
    static let lock = NSLock()
    nonisolated(unsafe) static var responses: [Response] = []
    nonisolated(unsafe) static var recordedRequests: [URLRequest] = []

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        responses = []
        recordedRequests = []
    }

    static func enqueue(_ response: Response) {
        lock.lock(); defer { lock.unlock() }
        responses.append(response)
    }

    static func popResponse(for request: URLRequest) -> Response? {
        lock.lock(); defer { lock.unlock() }
        recordedRequests.append(request)
        return responses.isEmpty ? nil : responses.removeFirst()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let stub = StubURLProtocol.popResponse(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class GitHubReleaseTransportTests: XCTestCase {
    private var session: URLSession!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        StubURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: config)
        suiteName = "orifold-transport-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        StubURLProtocol.reset()
    }

    private func releaseJSON(tag: String, dmgSize: Int = 42) -> Data {
        """
        {
          "tag_name": "\(tag)",
          "html_url": "https://github.com/udhawan97/Orifold/releases/tag/\(tag)",
          "published_at": "2026-07-08T00:00:00Z",
          "assets": [
            {"name": "Orifold-x-macOS-universal.dmg", "size": \(dmgSize)},
            {"name": "Orifold.zip", "size": 99}
          ]
        }
        """.data(using: .utf8)!
    }

    private func transport() -> GitHubReleaseTransport {
        GitHubReleaseTransport(session: session, defaults: defaults, repository: "udhawan97/Orifold")
    }

    func testDetectsNewerRelease() async throws {
        StubURLProtocol.enqueue(.init(status: 200, headers: ["ETag": "\"v1\""], body: releaseJSON(tag: "v0.9.0")))
        let outcome = try await transport().checkForUpdate(currentVersion: UpdateVersion(string: "0.8.4")!)
        guard case let .available(update) = outcome else { return XCTFail("expected available, got \(outcome)") }
        XCTAssertEqual(update.version, "0.9")
        XCTAssertEqual(update.assetSizeBytes, 42)
        XCTAssertNotNil(update.releaseNotesURL)
    }

    func testSameVersionIsUpToDate() async throws {
        StubURLProtocol.enqueue(.init(status: 200, headers: ["ETag": "\"v1\""], body: releaseJSON(tag: "v0.8.4")))
        let outcome = try await transport().checkForUpdate(currentVersion: UpdateVersion(string: "0.8.4")!)
        XCTAssertEqual(outcome, .upToDate)
    }

    /// The v0.8.5 regression guard: a 304 (unchanged release) must be re-compared against
    /// the *current* version, not blindly reported as up to date. Scenario: the app cached
    /// the ETag for release 0.9.0 while still running 0.8.4; the next check gets a 304, and
    /// must STILL surface 0.9.0 as available — the old code returned `.upToDate` here.
    func testStaleETag304StillSurfacesAvailableUpdate() async throws {
        let t = transport()
        // First check: 200 with a newer release than what we run → caches ETag + body.
        StubURLProtocol.enqueue(.init(status: 200, headers: ["ETag": "\"abc\""], body: releaseJSON(tag: "v0.9.0")))
        let first = try await t.checkForUpdate(currentVersion: UpdateVersion(string: "0.8.4")!)
        guard case .available = first else { return XCTFail("first check should surface the update") }

        // Second check: GitHub says 304 Not Modified. The release is still 0.9.0 and we're
        // still on 0.8.4, so the update MUST still be offered.
        StubURLProtocol.enqueue(.init(status: 304, headers: [:], body: Data()))
        let second = try await t.checkForUpdate(currentVersion: UpdateVersion(string: "0.8.4")!)
        guard case let .available(update) = second else {
            return XCTFail("304 must re-compare cached release, not report up-to-date. Got \(second)")
        }
        XCTAssertEqual(update.version, "0.9")

        // And the conditional request actually carried the cached ETag.
        let sentIfNoneMatch = StubURLProtocol.recordedRequests.last?.value(forHTTPHeaderField: "If-None-Match")
        XCTAssertEqual(sentIfNoneMatch, "\"abc\"")
    }

    /// A 304 whose cached release is NOT newer than the current version correctly stays
    /// up to date (e.g. the user upgraded to 0.9.0 and the cached release is also 0.9.0).
    func test304WithNonNewerCachedReleaseIsUpToDate() async throws {
        let t = transport()
        StubURLProtocol.enqueue(.init(status: 200, headers: ["ETag": "\"abc\""], body: releaseJSON(tag: "v0.9.0")))
        _ = try await t.checkForUpdate(currentVersion: UpdateVersion(string: "0.8.4")!)

        StubURLProtocol.enqueue(.init(status: 304, headers: [:], body: Data()))
        let outcome = try await t.checkForUpdate(currentVersion: UpdateVersion(string: "0.9.0")!)
        XCTAssertEqual(outcome, .upToDate)
    }

    /// The very first check never sends If-None-Match (no cached body to fall back to).
    func testFirstCheckSendsNoConditionalHeader() async throws {
        StubURLProtocol.enqueue(.init(status: 200, headers: ["ETag": "\"abc\""], body: releaseJSON(tag: "v0.8.4")))
        _ = try await transport().checkForUpdate(currentVersion: UpdateVersion(string: "0.8.4")!)
        XCTAssertNil(StubURLProtocol.recordedRequests.first?.value(forHTTPHeaderField: "If-None-Match"))
    }

    func testHTTPErrorThrows() async {
        StubURLProtocol.enqueue(.init(status: 500, headers: [:], body: Data()))
        do {
            _ = try await transport().checkForUpdate(currentVersion: UpdateVersion(string: "0.8.4")!)
            XCTFail("expected throw on HTTP 500")
        } catch {
            XCTAssertEqual(error as? UpdateTransportError, .httpStatus(500))
        }
    }

    func testUnparseableTagThrows() async {
        StubURLProtocol.enqueue(.init(status: 200, headers: ["ETag": "\"z\""], body: releaseJSON(tag: "not-a-version")))
        do {
            _ = try await transport().checkForUpdate(currentVersion: UpdateVersion(string: "0.8.4")!)
            XCTFail("expected throw on unparseable tag")
        } catch {
            XCTAssertEqual(error as? UpdateTransportError, .unparseableTag("not-a-version"))
        }
    }
}
