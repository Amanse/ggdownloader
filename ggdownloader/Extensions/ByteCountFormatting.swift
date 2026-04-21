import Foundation

extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Double {
    var formattedSpeed: String {
        let bytesPerSecond = Int64(self)
        if bytesPerSecond <= 0 { return "--" }
        return "\(ByteCountFormatter.string(fromByteCount: bytesPerSecond, countStyle: .file))/s"
    }
}

func formattedTimeRemaining(bytesRemaining: Int64, bytesPerSecond: Double) -> String {
    guard bytesPerSecond > 0 else { return "--" }
    let seconds = Double(bytesRemaining) / bytesPerSecond
    if seconds < 60 { return "\(Int(seconds))s" }
    if seconds < 3600 { return "\(Int(seconds / 60))m \(Int(seconds.truncatingRemainder(dividingBy: 60)))s" }
    return "\(Int(seconds / 3600))h \(Int((seconds / 60).truncatingRemainder(dividingBy: 60)))m"
}
