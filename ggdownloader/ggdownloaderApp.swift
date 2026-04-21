import SwiftUI

@main
struct ggdownloaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    DownloadManager.shared.reconnectTasks()
                }
        }
    }
}
