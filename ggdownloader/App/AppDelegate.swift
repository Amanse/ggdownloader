import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Accessing .shared ensures the session is recreated with the same identifier,
        // which reconnects it to the system daemon's completed tasks.
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }
}
