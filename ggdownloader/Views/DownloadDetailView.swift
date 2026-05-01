import SwiftUI

struct DownloadDetailView: View {
    let id: UUID
    @State private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss

    private var item: DownloadItem? {
        downloadManager.downloads.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let item {
                    content(item)
                } else {
                    ContentUnavailableView("Download not found", systemImage: "xmark.circle")
                }
            }
            .navigationTitle("Download Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ item: DownloadItem) -> some View {
        List {
            // Header section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: iconName(item))
                        .foregroundStyle(iconColor(item))
                        .font(.largeTitle)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.fileName)
                            .font(.headline)
                        statusBadge(item)
                    }
                }
                .padding(.vertical, 4)

                Text(item.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            // Progress section (active/paused downloads)
            if item.status == .downloading || item.status == .paused {
                Section("Progress") {
                    VStack(spacing: 8) {
                        ProgressView(value: item.progress)
                            .tint(item.status == .paused ? .orange : AccentColorManager.shared.accentColor)

                        HStack {
                            Text(item.downloadedBytes.formattedFileSize)
                                .foregroundStyle(.secondary)
                            if item.totalBytes > 0 {
                                Text("of \(item.totalBytes.formattedFileSize)")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(item.progress * 100))%")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Stats section
            Section("Info") {
                if item.status == .downloading && item.speed > 0 {
                    LabeledContent("Speed", value: item.speed.formattedSpeed)
                    LabeledContent("ETA", value: formattedTimeRemaining(
                        bytesRemaining: item.totalBytes - item.downloadedBytes,
                        bytesPerSecond: item.speed
                    ))
                }

                LabeledContent("Started", value: item.dateAdded.formatted(date: .omitted, time: .shortened) + " · " + item.dateAdded.formatted(.relative(presentation: .named)))

                if item.totalBytes > 0 {
                    LabeledContent("File Size", value: item.totalBytes.formattedFileSize)
                }

                if let completed = item.dateCompleted {
                    LabeledContent("Completed", value: completed.formatted(date: .omitted, time: .shortened))
                }
            }

            // Error section
            if item.status == .failed, let error = item.errorMessage {
                Section("Error") {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            // Actions section
            Section {
                if item.status == .downloading {
                    Button("Pause") {
                        downloadManager.pauseDownload(id: item.id)
                    }
                    .foregroundStyle(.orange)
                }
                if item.status == .paused || item.status == .failed {
                    Button("Resume") {
                        downloadManager.resumeDownload(id: item.id)
                    }
                    .foregroundStyle(.green)
                }
                if item.status != .completed && item.status != .cancelled {
                    Button("Cancel", role: .destructive) {
                        downloadManager.cancelDownload(id: item.id)
                        dismiss()
                    }
                }
                if item.status == .completed {
                    let fileURL = DownloadStore.shared.destinationURL(for: item.fileName)
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        ShareLink(item: fileURL) {
                            Label("Share File", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func iconName(_ item: DownloadItem) -> String {
        switch item.status {
        case .waiting:     "clock"
        case .downloading: "arrow.down.circle.fill"
        case .paused:      "pause.circle.fill"
        case .completed:   "checkmark.circle.fill"
        case .failed:      "xmark.circle.fill"
        case .cancelled:   "xmark.circle"
        }
    }

    private func iconColor(_ item: DownloadItem) -> Color {
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
    private func statusBadge(_ item: DownloadItem) -> some View {
        let color = iconColor(item)
        Text(item.status.rawValue.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
