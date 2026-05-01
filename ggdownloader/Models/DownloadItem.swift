import Foundation

struct DownloadFailure: Identifiable {
    let id = UUID()
    let fileName: String
    let message: String
}

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
    var speed: Double = 0   // bytes/sec, transient — excluded from persistence

    private enum CodingKeys: String, CodingKey {
        case id, url, fileName, status, progress, totalBytes, downloadedBytes
        case dateAdded, dateCompleted, errorMessage, taskIdentifier
    }

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
        taskIdentifier: Int? = nil,
        speed: Double = 0
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
        self.speed = speed
    }
}
