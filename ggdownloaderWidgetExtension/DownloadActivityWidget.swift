import SwiftUI
import WidgetKit
import ActivityKit

struct DownloadActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Downloading")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.attributes.fileName)
                                .font(.caption.bold())
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(Int(context.state.progress * 100))")
                                .font(.callout.bold())
                                .monospacedDigit()
                            Text("%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(context.state.speed)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Gauge(value: context.state.progress) {
                        EmptyView()
                    }
                    .gaugeStyle(.accessoryLinear)
                    .tint(
                        Gradient(colors: [.blue, .cyan])
                    )
                    .padding(.horizontal, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.bytesDownloaded.formattedFileSize)
                        Text("/")
                        Text(context.state.totalBytes > 0
                             ? context.state.totalBytes.formattedFileSize
                             : "Unknown")
                        Spacer()
                        Text(context.state.statusMessage)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Gauge(value: context.state.progress) {
                    Text("\(Int(context.state.progress * 100))")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.blue)
                .frame(width: 24, height: 24)
            } minimal: {
                Gauge(value: context.state.progress) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.blue)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<DownloadAttributes>

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: progressIcon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse, isActive: context.state.progress < 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(context.state.progress * 100))%")
                    .font(.title3.bold())
                    .monospacedDigit()
            }

            Gauge(value: context.state.progress) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
            .tint(Gradient(colors: [.blue, .cyan]))

            HStack {
                VStack(alignment: .leading) {
                    Text("Downloaded")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.bytesDownloaded.formattedFileSize)
                        .font(.caption.bold())
                }

                Spacer()

                VStack(alignment: .center) {
                    Text("Speed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.speed)
                        .font(.caption.bold())
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.totalBytes > 0
                         ? context.state.totalBytes.formattedFileSize
                         : "Unknown")
                    .font(.caption.bold())
                }
            }
        }
    }

    private var progressIcon: String {
        if context.state.progress >= 1.0 { return "checkmark.circle.fill" }
        return "arrow.down.circle.fill"
    }
}

// MARK: - Int64 extension (widget target needs its own)

private extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

// MARK: - Preview

#Preview(
    "Compact",
    as: .dynamicIsland(.compact),
    using: DownloadAttributes(
        fileName: "llama-3.2-8b.gguf",
        downloadID: UUID().uuidString
    )
) {
    DownloadActivityWidget()
} contentStates: {
    DownloadAttributes.ContentState(
        progress: 0.45,
        bytesDownloaded: 1_800_000_000,
        totalBytes: 4_000_000_000,
        statusMessage: "Downloading...",
        speed: "12.4 MB/s"
    )
}

#Preview(
    "Expanded",
    as: .dynamicIsland(.expanded),
    using: DownloadAttributes(
        fileName: "llama-3.2-8b.gguf",
        downloadID: UUID().uuidString
    )
) {
    DownloadActivityWidget()
} contentStates: {
    DownloadAttributes.ContentState(
        progress: 0.45,
        bytesDownloaded: 1_800_000_000,
        totalBytes: 4_000_000_000,
        statusMessage: "Downloading...",
        speed: "12.4 MB/s"
    )
    DownloadAttributes.ContentState(
        progress: 1.0,
        bytesDownloaded: 4_000_000_000,
        totalBytes: 4_000_000_000,
        statusMessage: "Download Complete",
        speed: "--"
    )
}

#Preview(
    "Lock Screen",
    as: .content,
    using: DownloadAttributes(
        fileName: "llama-3.2-8b.gguf",
        downloadID: UUID().uuidString
    )
) {
    DownloadActivityWidget()
} contentStates: {
    DownloadAttributes.ContentState(
        progress: 0.45,
        bytesDownloaded: 1_800_000_000,
        totalBytes: 4_000_000_000,
        statusMessage: "Downloading...",
        speed: "12.4 MB/s"
    )
}
