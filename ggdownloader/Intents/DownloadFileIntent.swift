import AppIntents
import Foundation

struct DownloadFileIntent: AppIntent {
    static let title: LocalizedStringResource = "Download File"
    static let description = IntentDescription(
        "Queue a file URL for download in GG Downloader.",
        categoryName: "Downloads"
    )
    static let openAppWhenRun: Bool = true

    @Parameter(title: "URL", description: "The URL of the file to download.", inputConnectionBehavior: .connectToPreviousIntentResult)
    var url: URL

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard url.scheme?.hasPrefix("http") == true else {
            throw DownloadIntentError.invalidURL
        }

        DownloadStore.shared.appendPendingURL(url.absoluteString)

        let displayName = url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent
        return .result(dialog: "Queued \"\(displayName)\" for download.")
    }
}

enum DownloadIntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidURL

    var localizedStringResource: LocalizedStringResource {
        "The URL must begin with http or https."
    }
}
