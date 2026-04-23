import SwiftUI

struct DownloadRowView: View {
    let item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    if item.status == .downloading {
                        Text(speedLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if item.status == .completed, let date = item.dateCompleted {
                        Text("Completed \(date.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if item.status == .failed, let error = item.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }

                Spacer()

                statusBadge
            }

            if item.status == .downloading || item.status == .paused {
                VStack(spacing: 4) {
                    ProgressView(value: item.progress)
                        .tint(item.status == .paused ? .orange : AccentColorManager.shared.accentColor)

                    HStack {
                        Text(item.downloadedBytes.formattedFileSize)
                            .foregroundStyle(.secondary)
                        if item.totalBytes > 0 {
                            Text("/ \(item.totalBytes.formattedFileSize)")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(item.progress * 100))%")
                            .fontWeight(.medium)
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch item.status {
        case .waiting:     "clock"
        case .downloading: "arrow.down.circle.fill"
        case .paused:      "pause.circle.fill"
        case .completed:   "checkmark.circle.fill"
        case .failed:      "xmark.circle.fill"
        case .cancelled:   "xmark.circle"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .waiting:     .gray
        case .downloading: AccentColorManager.shared.accentColor
        case .paused:      .orange
        case .completed:   .green
        case .failed:      .red
        case .cancelled:   .gray
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        Text(item.status.rawValue.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(iconColor.opacity(0.15), in: Capsule())
            .foregroundStyle(iconColor)
    }

    private var speedLabel: String {
        if item.totalBytes > 0 {
            let remaining = item.totalBytes - item.downloadedBytes
            return item.totalBytes.formattedFileSize + " total"
        }
        return item.downloadedBytes.formattedFileSize + " downloaded"
    }
}

#Preview {
    List {
        DownloadRowView(item: DownloadItem(
            url: URL(string: "https://example.com/file.zip")!,
            fileName: "large-model.gguf",
            status: .downloading,
            progress: 0.45,
            totalBytes: 4_000_000_000,
            downloadedBytes: 1_800_000_000
        ))
        DownloadRowView(item: DownloadItem(
            url: URL(string: "https://example.com/file2.zip")!,
            fileName: "small-file.zip",
            status: .completed,
            progress: 1.0,
            totalBytes: 50_000_000,
            downloadedBytes: 50_000_000,
            dateCompleted: Date()
        ))
        DownloadRowView(item: DownloadItem(
            url: URL(string: "https://example.com/file3.zip")!,
            fileName: "failed-download.bin",
            status: .failed,
            errorMessage: "Network connection lost"
        ))
    }
}
