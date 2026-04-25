import SwiftUI

@main
struct ggdownloaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var accentManager = AccentColorManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(accentManager.accentColor)
                .onAppear {
                    DownloadManager.shared.reconnectTasks()
                    processPendingDownloads()
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                processPendingDownloads()
            }
        }
    }

    private func processPendingDownloads() {
        let store = DownloadStore.shared
        let pending = store.pendingURLStrings()
        guard !pending.isEmpty else { return }
        store.clearPendingURLs()
        for urlString in pending {
            guard
                let url = URL(string: urlString),
                let scheme = url.scheme,
                scheme.hasPrefix("http")
            else { continue }
            DownloadManager.shared.startDownload(url: url)
        }
    }

    // Handles ggdownloader://download?url=<percent-encoded-http-url>
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "ggdownloader",
              url.host == "download",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let downloadURL = URL(string: urlParam),
              downloadURL.scheme?.hasPrefix("http") == true
        else { return }
        DownloadStore.shared.appendPendingURL(downloadURL.absoluteString)
        processPendingDownloads()
    }
}
