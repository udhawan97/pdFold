import Foundation

/// One entry in the "Recently Viewed Files" list on the empty-state screen.
/// Identity for de-duping/updating is the resolved file path, not `id` —
/// `id` only exists to satisfy `Identifiable` for SwiftUI diffing.
struct RecentFileEntry: Codable, Identifiable, Equatable {
    var id: UUID
    /// Security-scoped bookmark for reopening across launches under App Sandbox.
    /// Nil if bookmark creation failed at record time — falls back to `path`.
    var bookmarkData: Data?
    var path: String
    var displayName: String
    var lastOpened: Date
    var pageCount: Int?
    /// 0-based index of the page last viewed, for the "Resume · p. N" affordance.
    var lastPageOpened: Int?
    /// Filename (without extension) of the cached thumbnail PNG, if generated.
    var thumbnailCacheKey: String?
    /// Set after a thumbnail generation attempt fails, so it isn't retried every launch.
    var thumbnailFailed: Bool = false

    var url: URL { URL(fileURLWithPath: path) }
}
