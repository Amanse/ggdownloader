import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activities: [UUID: Activity<DownloadAttributes>] = [:]
    private var lastUpdateTime: [UUID: Date] = [:]
    private let updateInterval: TimeInterval = 1.0

    private init() {}

    func startActivity(for item: DownloadItem) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DownloadAttributes(
            fileName: item.fileName,
            downloadID: item.id.uuidString
        )
        let initialState = DownloadAttributes.ContentState(
            progress: 0,
            bytesDownloaded: 0,
            totalBytes: item.totalBytes,
            statusMessage: "Starting...",
            speed: "--",
            eta: "--"
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil)
            )
            activities[item.id] = activity
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    func updateProgress(
        downloadID: UUID,
        progress: Double,
        bytesDownloaded: Int64,
        totalBytes: Int64,
        speed: Double,
        eta: String
    ) {
        let now = Date()
        if let last = lastUpdateTime[downloadID], now.timeIntervalSince(last) < updateInterval {
            return
        }
        lastUpdateTime[downloadID] = now

        guard let activity = activities[downloadID] else { return }

        let state = DownloadAttributes.ContentState(
            progress: progress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            statusMessage: "Downloading...",
            speed: speed.formattedSpeed,
            eta: eta
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func endActivity(downloadID: UUID, success: Bool) {
        guard let activity = activities[downloadID] else { return }

        let finalState = DownloadAttributes.ContentState(
            progress: success ? 1.0 : 0,
            bytesDownloaded: 0,
            totalBytes: 0,
            statusMessage: success ? "Download Complete" : "Download Failed",
            speed: "--",
            eta: "--"
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 30)
            )
        }
        activities.removeValue(forKey: downloadID)
        lastUpdateTime.removeValue(forKey: downloadID)
    }

    func endActivity(downloadID: UUID, cancelled: Bool) {
        guard let activity = activities[downloadID] else { return }

        let finalState = DownloadAttributes.ContentState(
            progress: 0,
            bytesDownloaded: 0,
            totalBytes: 0,
            statusMessage: cancelled ? "Cancelled" : "Paused",
            speed: "--",
            eta: "--"
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        activities.removeValue(forKey: downloadID)
        lastUpdateTime.removeValue(forKey: downloadID)
    }
}
