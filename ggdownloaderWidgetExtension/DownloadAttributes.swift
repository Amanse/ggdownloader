// Widget extension target copy of DownloadAttributes.
// The app target has an identical copy at ggdownloader/Models/DownloadAttributes.swift.
// Both define the same struct independently in their respective modules.
import ActivityKit
import Foundation

struct DownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        var progress: Double
        var bytesDownloaded: Int64
        var totalBytes: Int64
        var statusMessage: String
        var speed: String
        var eta: String
    }

    var fileName: String
    var downloadID: String
}
