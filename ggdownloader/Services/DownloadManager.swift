import Foundation
import Observation

@Observable
@MainActor
final class DownloadManager: NSObject {
    static let shared = DownloadManager()

    var downloads: [DownloadItem] = []
    var recentFailure: DownloadFailure? = nil

    // Called by AppDelegate to notify completion handler
    nonisolated(unsafe) var backgroundCompletionHandler: (() -> Void)?

    private nonisolated(unsafe) var urlSession: URLSession!
    private nonisolated(unsafe) var taskToDownloadID: [Int: UUID] = [:]
    private nonisolated(unsafe) var speedTracker: [UUID: SpeedTracker] = [:]
    private nonisolated(unsafe) var resolvedFileNames: Set<UUID> = []

    private let store = DownloadStore.shared

    override private init() {
        super.init()
        store.prepareDownloadsDirectory()

        let config = URLSessionConfiguration.background(
            withIdentifier: "\(Bundle.main.bundleIdentifier!).downloads"
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.httpMaximumConnectionsPerHost = 4

        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        downloads = store.load()
    }

    // MARK: - Public API

    func startDownload(url: URL, fileName: String? = nil) {
        let name = fileName?.isEmpty == false ? fileName! : url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        var item = DownloadItem(url: url, fileName: name, status: .downloading)
        downloads.append(item)
        store.save(downloads)

        let task = urlSession.downloadTask(with: url)
        task.taskDescription = item.id.uuidString
        taskToDownloadID[task.taskIdentifier] = item.id
        speedTracker[item.id] = SpeedTracker()

        // Update taskIdentifier in item
        if let idx = downloads.firstIndex(where: { $0.id == item.id }) {
            downloads[idx].taskIdentifier = task.taskIdentifier
            item = downloads[idx]
        }

        task.resume()
        LiveActivityManager.shared.startActivity(for: item)
        store.save(downloads)
    }

    func pauseDownload(id: UUID) {
        guard let taskID = taskIdentifier(for: id) else { return }
        let tasks = tasksSnapshot()
        guard let task = tasks.first(where: { $0.taskIdentifier == taskID }) as? URLSessionDownloadTask else { return }

        task.cancel(byProducingResumeData: { [weak self] resumeData in
            guard let self else { return }
            if let data = resumeData {
                self.store.saveResumeData(data, for: id)
            }
            Task { @MainActor in
                guard let idx = self.downloads.firstIndex(where: { $0.id == id }) else { return }
                self.downloads[idx].speed = 0
                self.updateStatus(id: id, status: .paused)
                self.speedTracker.removeValue(forKey: id)
                LiveActivityManager.shared.endActivity(downloadID: id, cancelled: false)
            }
        })
    }

    func resumeDownload(id: UUID) {
        guard let resumeData = store.loadResumeData(for: id) else {
            // No resume data - restart from scratch
            guard let item = downloads.first(where: { $0.id == id }) else { return }
            store.deleteResumeData(for: id)
            updateStatus(id: id, status: .downloading)
            let task = urlSession.downloadTask(with: item.url)
            task.taskDescription = id.uuidString
            taskToDownloadID[task.taskIdentifier] = id
            speedTracker[id] = SpeedTracker()
            updateTaskIdentifier(id: id, taskID: task.taskIdentifier)
            task.resume()
            if let updated = downloads.first(where: { $0.id == id }) {
                LiveActivityManager.shared.startActivity(for: updated)
            }
            return
        }

        updateStatus(id: id, status: .downloading)
        let task = urlSession.downloadTask(withResumeData: resumeData)
        task.taskDescription = id.uuidString
        taskToDownloadID[task.taskIdentifier] = id
        speedTracker[id] = SpeedTracker()
        updateTaskIdentifier(id: id, taskID: task.taskIdentifier)
        store.deleteResumeData(for: id)
        task.resume()
        if let item = downloads.first(where: { $0.id == id }) {
            LiveActivityManager.shared.startActivity(for: item)
        }
        store.save(downloads)
    }

    func cancelDownload(id: UUID) {
        if let taskID = taskIdentifier(for: id) {
            let tasks = tasksSnapshot()
            tasks.first(where: { $0.taskIdentifier == taskID })?.cancel()
        }
        store.deleteResumeData(for: id)
        speedTracker.removeValue(forKey: id)
        resolvedFileNames.remove(id)
        updateStatus(id: id, status: .cancelled)
        LiveActivityManager.shared.endActivity(downloadID: id, cancelled: true)
    }

    func clearCompleted() {
        let toRemove = downloads.filter {
            [.completed, .failed, .cancelled].contains($0.status)
        }
        for item in toRemove {
            if item.status == .completed {
                store.deleteFile(named: item.fileName)
            }
            store.deleteResumeData(for: item.id)
        }
        downloads.removeAll { [.completed, .failed, .cancelled].contains($0.status) }
        store.save(downloads)
    }

    // MARK: - Error Helpers

    private nonisolated func httpErrorMessage(_ code: Int) -> String {
        switch code {
        case 400: return "Bad request (400)"
        case 401: return "Authentication required (401)"
        case 403: return "Access denied — you don't have permission to download this file (403)"
        case 404: return "File not found — the URL may be incorrect (404)"
        case 410: return "File no longer available (410)"
        case 429: return "Too many requests — try again later (429)"
        case 500...599: return "Server error (\(code)) — try again later"
        default: return "HTTP error \(code)"
        }
    }

    private nonisolated func friendlyErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case -1022: return "HTTP not allowed — the server requires a secure connection. Use an HTTPS URL."
        case -1001: return "Connection timed out — check your network and try again"
        case -1009: return "No internet connection"
        case -1004: return "Could not connect to the server"
        case -1003: return "Server not found — check the URL"
        case -1200: return "Secure connection failed (SSL error)"
        default:    return error.localizedDescription
        }
    }

    // MARK: - Reconnect on Launch

    func reconnectTasks() {
        urlSession.getAllTasks { [weak self] tasks in
            guard let self else { return }
            Task { @MainActor in
                for task in tasks {
                    guard let uuidString = task.taskDescription,
                          let id = UUID(uuidString: uuidString) else { continue }
                    self.taskToDownloadID[task.taskIdentifier] = id
                    self.speedTracker[id] = SpeedTracker()
                    self.updateTaskIdentifier(id: id, taskID: task.taskIdentifier)
                    if task.state == .running {
                        self.updateStatus(id: id, status: .downloading)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func taskIdentifier(for downloadID: UUID) -> Int? {
        taskToDownloadID.first(where: { $0.value == downloadID })?.key
    }

    private func tasksSnapshot() -> [URLSessionTask] {
        var result: [URLSessionTask] = []
        let sem = DispatchSemaphore(value: 0)
        urlSession.getAllTasks { tasks in
            result = tasks
            sem.signal()
        }
        sem.wait()
        return result
    }

    private func updateStatus(id: UUID, status: DownloadStatus) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx].status = status
        if status == .completed { downloads[idx].dateCompleted = Date() }
        store.save(downloads)
    }

    private func updateTaskIdentifier(id: UUID, taskID: Int) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx].taskIdentifier = taskID
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard
            let uuidString = downloadTask.taskDescription,
            let id = UUID(uuidString: uuidString)
        else { return }

        let store = DownloadStore.shared
        store.prepareDownloadsDirectory()

        // Check HTTP status before saving — download tasks don't error on 4xx/5xx
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let message = httpErrorMessage(httpResponse.statusCode)
            resolvedFileNames.remove(id)
            Task { @MainActor in
                self.markFailed(id: id, error: message)
            }
            return
        }

        // Determine file name - prefer server-suggested name
        let suggestedName = downloadTask.response?.suggestedFilename
        var fileName: String

        // Get stored fileName from downloads on main thread (snapshot)
        var storedName: String?
        DispatchQueue.main.sync {
            storedName = self.downloads.first(where: { $0.id == id })?.fileName
        }

        fileName = suggestedName ?? storedName ?? location.lastPathComponent

        // Sanitize: remove path separators and colons that break file creation
        fileName = fileName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if fileName.isEmpty { fileName = "download" }

        // Try custom download location first, fall back to default
        var destination: URL
        var scopedURL: URL?

        if let customDir = store.resolveCustomDownloadDirectory() {
            customDir.startAccessingSecurityScopedResource()
            scopedURL = customDir
            destination = customDir.appendingPathComponent(fileName)
        } else {
            destination = store.destinationURL(for: fileName)
        }

        // Remove existing file at destination
        try? FileManager.default.removeItem(at: destination)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            // If custom location failed, fall back to default
            if scopedURL != nil {
                scopedURL?.stopAccessingSecurityScopedResource()
                scopedURL = nil
                destination = store.destinationURL(for: fileName)
                try? FileManager.default.removeItem(at: destination)
                do {
                    try FileManager.default.moveItem(at: location, to: destination)
                } catch {
                    Task { @MainActor in
                        self.markFailed(id: id, error: "Failed to save file: \(error.localizedDescription)")
                    }
                    return
                }
            } else {
                Task { @MainActor in
                    self.markFailed(id: id, error: "Failed to save file: \(error.localizedDescription)")
                }
                return
            }
        }

        scopedURL?.stopAccessingSecurityScopedResource()

        Task { @MainActor in
            guard let idx = self.downloads.firstIndex(where: { $0.id == id }) else { return }
            self.downloads[idx].status = .completed
            self.downloads[idx].progress = 1.0
            self.downloads[idx].dateCompleted = Date()
            self.downloads[idx].fileName = fileName
            self.downloads[idx].speed = 0
            self.speedTracker.removeValue(forKey: id)
            self.resolvedFileNames.remove(id)
            self.store.save(self.downloads)
            LiveActivityManager.shared.endActivity(downloadID: id, success: true)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard
            let uuidString = downloadTask.taskDescription,
            let id = UUID(uuidString: uuidString)
        else { return }

        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0

        let speed = speedTracker[id]?.record(bytes: totalBytesWritten) ?? 0

        // Resolve filename from Content-Disposition header on first write
        let needsNameResolution = !resolvedFileNames.contains(id)
        var resolvedName: String? = nil
        if needsNameResolution {
            resolvedFileNames.insert(id)
            if let suggested = downloadTask.response?.suggestedFilename, !suggested.isEmpty {
                var sanitized = suggested
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: ":", with: "_")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if sanitized.isEmpty { sanitized = "download" }
                resolvedName = sanitized
            }
        }

        let eta = totalBytesExpectedToWrite > 0
            ? formattedTimeRemaining(
                bytesRemaining: totalBytesExpectedToWrite - totalBytesWritten,
                bytesPerSecond: speed)
            : "--"

        Task { @MainActor in
            guard let idx = self.downloads.firstIndex(where: { $0.id == id }) else { return }
            self.downloads[idx].progress = progress
            self.downloads[idx].downloadedBytes = totalBytesWritten
            self.downloads[idx].totalBytes = totalBytesExpectedToWrite
            self.downloads[idx].status = .downloading
            self.downloads[idx].speed = speed
            if let name = resolvedName {
                self.downloads[idx].fileName = name
                self.store.save(self.downloads)
            }

            LiveActivityManager.shared.updateProgress(
                downloadID: id,
                progress: progress,
                bytesDownloaded: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite,
                speed: speed,
                eta: eta
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }

        guard
            let uuidString = task.taskDescription,
            let id = UUID(uuidString: uuidString)
        else { return }

        let nsError = error as NSError

        // Check for resume data (user-initiated cancel or network failure)
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            DownloadStore.shared.saveResumeData(resumeData, for: id)
            resolvedFileNames.remove(id)
            Task { @MainActor in
                guard let idx = self.downloads.firstIndex(where: { $0.id == id }) else { return }
                self.downloads[idx].speed = 0
                self.updateStatus(id: id, status: .paused)
                self.speedTracker.removeValue(forKey: id)
                LiveActivityManager.shared.endActivity(downloadID: id, cancelled: false)
            }
        } else if nsError.code == NSURLErrorCancelled {
            // Explicit cancel, already handled in cancelDownload()
        } else {
            let message = friendlyErrorMessage(error)
            Task { @MainActor in
                self.markFailed(id: id, error: message)
            }
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }

    // MARK: - Private helper (must be called on MainActor)
    @MainActor
    private func markFailed(id: UUID, error: String) {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx].status = .failed
        downloads[idx].errorMessage = error
        downloads[idx].speed = 0
        speedTracker.removeValue(forKey: id)
        resolvedFileNames.remove(id)
        store.save(downloads)
        LiveActivityManager.shared.endActivity(downloadID: id, success: false)
        recentFailure = DownloadFailure(fileName: downloads[idx].fileName, message: error)
    }
}

// MARK: - SpeedTracker

final class SpeedTracker: @unchecked Sendable {
    private var lastBytes: Int64 = 0
    private var lastTime: Date = Date()
    private var smoothedSpeed: Double = 0
    private let smoothingFactor: Double = 0.3

    func record(bytes: Int64) -> Double {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTime)
        guard elapsed > 0 else { return smoothedSpeed }

        let bytesDelta = bytes - lastBytes
        let instantSpeed = Double(bytesDelta) / elapsed

        smoothedSpeed = smoothingFactor * instantSpeed + (1 - smoothingFactor) * smoothedSpeed

        lastBytes = bytes
        lastTime = now
        return smoothedSpeed
    }
}
