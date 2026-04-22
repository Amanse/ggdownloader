import SwiftUI

@main
struct ggdownloaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    DownloadManager.shared.reconnectTasks()
                    processPendingDownloads()
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
}
