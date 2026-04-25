import Foundation

final class DownloadStore: Sendable {
    static let shared = DownloadStore()

    private let downloadsKey = "downloads"
    private let resumeDataDirectory: URL
    private let fileManager = FileManager.default
    private let defaults: UserDefaults?

    private init() {
        let appGroupID = "group.sanuki.ggdownloader"
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        resumeDataDirectory = container.appendingPathComponent("ResumeData", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: resumeDataDirectory,
            withIntermediateDirectories: true
        )

        defaults = UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Download Items

    func save(_ downloads: [DownloadItem]) {
        guard let data = try? JSONEncoder().encode(downloads) else { return }
        defaults?.set(data, forKey: downloadsKey)
    }

    func load() -> [DownloadItem] {
        guard
            let data = defaults?.data(forKey: downloadsKey),
            let items = try? JSONDecoder().decode([DownloadItem].self, from: data)
        else { return [] }
        return items
    }

    // MARK: - Resume Data

    func saveResumeData(_ data: Data, for downloadID: UUID) {
        let url = resumeDataDirectory.appendingPathComponent(downloadID.uuidString)
        try? data.write(to: url, options: .atomic)
    }

    func loadResumeData(for downloadID: UUID) -> Data? {
        let url = resumeDataDirectory.appendingPathComponent(downloadID.uuidString)
        return try? Data(contentsOf: url)
    }

    func deleteResumeData(for downloadID: UUID) {
        let url = resumeDataDirectory.appendingPathComponent(downloadID.uuidString)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Downloaded Files

    var downloadsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    func prepareDownloadsDirectory() {
        try? fileManager.createDirectory(
            at: downloadsDirectory,
            withIntermediateDirectories: true
        )
    }

    func destinationURL(for fileName: String) -> URL {
        downloadsDirectory.appendingPathComponent(fileName)
    }

    func totalDownloadedSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: downloadsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
        return total
    }

    func deleteFile(named fileName: String) {
        let url = downloadsDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Custom Download Location

    private let downloadBookmarkKey = "customDownloadLocationBookmark"

    func saveDownloadLocationBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        defaults?.set(data, forKey: downloadBookmarkKey)
    }

    func resolveCustomDownloadDirectory() -> URL? {
        guard let data = defaults?.data(forKey: downloadBookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            // Re-save fresh bookmark
            saveDownloadLocationBookmark(for: url)
        }

        // Verify directory is still accessible
        guard url.startAccessingSecurityScopedResource() else { return nil }
        let exists = fileManager.isWritableFile(atPath: url.path)
        url.stopAccessingSecurityScopedResource()
        guard exists else { return nil }

        return url
    }

    func clearCustomDownloadLocation() {
        defaults?.removeObject(forKey: downloadBookmarkKey)
    }

    func customDownloadLocationDisplayName() -> String? {
        resolveCustomDownloadDirectory()?.lastPathComponent
    }

    // MARK: - Accent Color

    private let accentColorKey = "accentColorHex"

    func saveAccentColor(_ hex: String) {
        defaults?.set(hex, forKey: accentColorKey)
    }

    func loadAccentColorHex() -> String {
        defaults?.string(forKey: accentColorKey) ?? "#007AFF"
    }

    // MARK: - Pending URLs (from Share Extension)

    private let pendingURLsKey = "pendingDownloadURLs"

    func pendingURLStrings() -> [String] {
        // Force re-read from disk — share extension writes from separate process
        defaults?.synchronize()
        return defaults?.stringArray(forKey: pendingURLsKey) ?? []
    }

    func appendPendingURL(_ urlString: String) {
        var pending = defaults?.stringArray(forKey: pendingURLsKey) ?? []
        pending.append(urlString)
        defaults?.set(pending, forKey: pendingURLsKey)
        defaults?.synchronize()
    }

    func clearPendingURLs() {
        defaults?.removeObject(forKey: pendingURLsKey)
    }
}
