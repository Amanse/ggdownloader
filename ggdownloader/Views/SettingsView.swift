import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var downloadManager = DownloadManager.shared
    @State private var showClearConfirm = false
    @State private var totalSize: Int64 = 0
    @State private var showFolderPicker = false
    @State private var customLocationName: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    AccentColorPickerView()
                }

                Section("Download Location") {
                    LabeledContent("Save to") {
                        Text(customLocationName ?? "Default (Downloads)")
                            .foregroundStyle(.secondary)
                    }
                    Button("Choose Location") {
                        showFolderPicker = true
                    }
                    if customLocationName != nil {
                        Button("Reset to Default") {
                            DownloadStore.shared.clearCustomDownloadLocation()
                            customLocationName = nil
                        }
                    }
                }

                Section("Storage") {
                    LabeledContent("Downloaded Files", value: totalSize.formattedFileSize)
                    Button("Clear Completed Downloads", role: .destructive) {
                        showClearConfirm = true
                    }
                }

                Section("Downloads") {
                    let activeCount = downloadManager.downloads.filter {
                        [.waiting, .downloading].contains($0.status)
                    }.count
                    LabeledContent("Active Downloads", value: "\(activeCount)")

                    let completedCount = downloadManager.downloads.filter {
                        $0.status == .completed
                    }.count
                    LabeledContent("Completed Downloads", value: "\(completedCount)")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                    LabeledContent("Source Code") {
                        Link("GitHub", destination: URL(string: "https://github.com/Amanse/ggdownloader")!)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                totalSize = DownloadStore.shared.totalDownloadedSize()
                customLocationName = DownloadStore.shared.customDownloadLocationDisplayName()
            }
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result {
                    DownloadStore.shared.saveDownloadLocationBookmark(for: url)
                    customLocationName = url.lastPathComponent
                }
            }
            .confirmationDialog(
                "Clear all completed, failed, and cancelled downloads?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Downloads", role: .destructive) {
                    downloadManager.clearCompleted()
                    totalSize = DownloadStore.shared.totalDownloadedSize()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
