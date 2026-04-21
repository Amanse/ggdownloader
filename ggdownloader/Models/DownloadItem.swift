import Foundation

enum DownloadStatus: String, Codable, Sendable {
    case waiting
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

struct DownloadItem: Identifiable, Codable, Sendable {
    let id: UUID
    let url: URL
    var fileName: String
    var status: DownloadStatus
    var progress: Double
    var totalBytes: Int64
    var downloadedBytes: Int64
    var dateAdded: Date
    var dateCompleted: Date?
    var errorMessage: String?
    var taskIdentifier: Int?

    init(
        id: UUID = UUID(),
        url: URL,
        fileName: String,
        status: DownloadStatus = .waiting,
        progress: Double = 0,
        totalBytes: Int64 = 0,
        downloadedBytes: Int64 = 0,
        dateAdded: Date = Date(),
        dateCompleted: Date? = nil,
        errorMessage: String? = nil,
        taskIdentifier: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.status = status
        self.progress = progress
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.dateAdded = dateAdded
        self.dateCompleted = dateCompleted
        self.errorMessage = errorMessage
        self.taskIdentifier = taskIdentifier
    }
}
