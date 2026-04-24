import AppIntents

struct GGDownloaderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DownloadFileIntent(),
            phrases: [
                "Download a file with \(.applicationName)",
                "Add a download to \(.applicationName)",
                "Queue a download in \(.applicationName)",
                "Download URL with \(.applicationName)"
            ],
            shortTitle: "Download File",
            systemImageName: "arrow.down.circle"
        )
    }
}
