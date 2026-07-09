import Foundation

/// Check-only update transport: asks the GitHub Releases API for the latest *stable*
/// release and compares its tag to the running version. This is the transport that ships
/// before Sparkle — it works today under the sandbox because it makes only an outbound
/// HTTPS GET (the `network.client` entitlement, already granted) and never tries to
/// download or replace the bundle.
///
/// `releases/latest` deliberately excludes prereleases, so the `Orifold-latest` dev-channel
/// prerelease is ignored and only tagged `v*` / `release-v*` releases are ever offered —
/// which is also what keeps the check from ever proposing a downgrade.
struct GitHubReleaseTransport: UpdateTransport {
    /// `owner/repo` from the release URLs the pipeline already publishes.
    static let repository = "udhawan97/Orifold"

    private let session: URLSession
    private let defaults: UserDefaults
    private let repository: String

    init(session: URLSession = .shared, defaults: UserDefaults = .standard, repository: String = GitHubReleaseTransport.repository) {
        self.session = session
        self.defaults = defaults
        self.repository = repository
    }

    private var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    private var etagDefaultsKey: String { "orifoldUpdateLatestETag" }
    /// The raw response body from the last 200, cached alongside its ETag. A 304 means
    /// "the release GitHub would return is unchanged from this," NOT "you're up to date" —
    /// those are different claims, and conflating them previously made every check after
    /// the first permanently report `.upToDate` regardless of `currentVersion`. Re-running
    /// the exact same decode+compare path against this cached body on a 304 keeps the two
    /// response paths honest with each other instead of duplicating the comparison logic.
    private var cachedBodyDefaultsKey: String { "orifoldUpdateLatestReleaseBody" }

    func checkForUpdate(currentVersion: UpdateVersion) async throws -> UpdateCheckOutcome {
        let cachedBody = defaults.data(forKey: cachedBodyDefaultsKey)
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Orifold", forHTTPHeaderField: "User-Agent")
        // Conditional GET so unchanged releases don't count against the API rate limit.
        // Only sent when we also have the cached body a 304 would fall back to — otherwise
        // a 304 would have nothing to compare against.
        if let etag = defaults.string(forKey: etagDefaultsKey), cachedBody != nil {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateTransportError.badResponse
        }

        let effectiveData: Data
        if http.statusCode == 304, let cachedBody {
            effectiveData = cachedBody
        } else if (200...299).contains(http.statusCode) {
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                defaults.set(etag, forKey: etagDefaultsKey)
            }
            defaults.set(data, forKey: cachedBodyDefaultsKey)
            effectiveData = data
        } else {
            throw UpdateTransportError.httpStatus(http.statusCode)
        }

        let release: GitHubRelease
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            release = try decoder.decode(GitHubRelease.self, from: effectiveData)
        } catch {
            throw UpdateTransportError.decoding(String(describing: error))
        }

        guard let latest = UpdateVersion(string: release.tagName) else {
            throw UpdateTransportError.unparseableTag(release.tagName)
        }
        guard latest > currentVersion else { return .upToDate }

        // Prefer the DMG asset's size for the download chip; fall back to the zip.
        let asset = release.assets.first { $0.name.hasSuffix(".dmg") }
            ?? release.assets.first { $0.name.hasSuffix(".zip") }

        return .available(AvailableUpdate(
            version: latest.description,
            currentVersion: currentVersion.description,
            releaseNotesURL: release.htmlURL,
            downloadPageURL: URL(string: "https://github.com/\(repository)/releases/latest"),
            publishedAt: release.publishedAt,
            assetSizeBytes: asset?.size
        ))
    }
}

enum UpdateTransportError: Error, Equatable {
    case badResponse
    case httpStatus(Int)
    case decoding(String)
    case unparseableTag(String)
}

/// Minimal slice of the GitHub Releases API payload we actually read.
private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL?
    let publishedAt: Date?
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let size: Int
    }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}
