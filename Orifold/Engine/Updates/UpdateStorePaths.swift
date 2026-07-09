import Foundation

/// Shared filesystem locations for the update subsystem. Everything lives beside the
/// existing `recents.json` under `Application Support/Orifold/`, so bundle swaps and
/// rollbacks — which only replace the `.app` — never touch any of it.
enum UpdateStorePaths {
    /// `~/Library/Application Support/Orifold`, created on first access. Falls back to a
    /// temporary directory only if Application Support is somehow unavailable, matching
    /// `RecentsStore`'s defensive posture.
    static var supportDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = support.appendingPathComponent("Orifold", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// Where pre-update autosave snapshots and their sidecar metadata live.
    static func recoveryDirectory(in base: URL = supportDirectory) -> URL {
        let dir = base.appendingPathComponent("Recovery", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Where the single previous-version bundle archive and its manifest live.
    static func rollbackDirectory(in base: URL = supportDirectory) -> URL {
        let dir = base.appendingPathComponent("Rollback", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A clearly-scoped, updater-owned cache for downloaded update artifacts and staging
    /// (zips/dmgs, staged bundles, temp dirs). This is the *only* directory the artifact
    /// cleaner is allowed to empty wholesale — nothing here is user data. Kept deliberately
    /// separate from `Recovery/` (which holds the user's pre-update work and is never
    /// auto-deleted).
    static func updaterCacheDirectory(in base: URL = supportDirectory) -> URL {
        let dir = base.appendingPathComponent("UpdaterCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Directory names the artifact cleaner is permitted to operate inside. A blast-radius
    /// guard: the cleaner refuses any directory whose last path component isn't in this set,
    /// so it can never be pointed at `Recovery/`, the support root, or the home folder.
    static let cleanerOwnedDirectoryNames: Set<String> = ["UpdaterCache", "Rollback"]
}
