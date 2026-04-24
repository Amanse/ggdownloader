import AppIntents
import Foundation

struct DownloadFileIntent: AppIntent {
    static let title: LocalizedStringResource = "Download File"
    static let description = IntentDescription(
        "Queue a file URL for download in GG Downloader.",
        categoryName: "Downloads"
    )
    static let openAppWhenRun: Bool = false

    @Parameter(title: "URL", description: "The URL of the file to download.", inputConnectionBehavior: .connectToPreviousIntentResult)
    var url: URL

    @Parameter(title: "File Name", description: "Optional custom name for the downloaded file.")
    var fileName: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard url.scheme?.hasPrefix("http") == true else {
            throw DownloadIntentError.invalidURL
        }

        let appGroupID = "group.sanuki.ggdownloader"
        let pendingKey = "pendingDownloadURLs"
        let defaults = UserDefaults(suiteName: appGroupID)
        var pending = defaults?.stringArray(forKey: pendingKey) ?? []
        pending.append(url.absoluteString)
        defaults?.set(pending, forKey: pendingKey)
        defaults?.synchronize()

        let displayName = fileName?.isEmpty == false ? fileName! :
            url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent
        return .result(dialog: "Queued \"\(displayName)\" for download.")
    }
}

enum DownloadIntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidURL

    var localizedStringResource: LocalizedStringResource {
        "The URL must begin with http or https."
    }
}
