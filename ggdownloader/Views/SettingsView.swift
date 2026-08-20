import SwiftUI
import StoreKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var downloadManager = DownloadManager.shared
    @State private var tipJarManager = TipJarManager.shared
    @State private var showClearConfirm = false
    @State private var totalSize: Int64 = 0
    @State private var showFolderPicker = false
    @State private var customLocationName: String?
    @State private var showTipJar = false

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

                if showTipJar {
                    Section {
                        tipJarContent
                    }
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
                showTipJar = DownloadStore.shared.shouldShowTipJar
            }
            .onChange(of: tipJarManager.purchaseState) { _, newValue in
                if newValue == .success {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation {
                            DownloadStore.shared.hasDismissedTipJar = true
                            showTipJar = false
                        }
                    }
                }
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

    // MARK: - Tip Jar

    @ViewBuilder
    private var tipJarContent: some View {
        VStack(spacing: 12) {
            Label("Support Development", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(.pink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Enjoying the app? Leave a tip to help keep development going!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if tipJarManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if tipJarManager.purchaseState == .success {
                Label("Thank you!", systemImage: "heart.circle.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.pink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if !tipJarManager.tips.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(tipJarManager.tips.enumerated()), id: \.element.id) { index, product in
                        tipButton(for: product, emoji: tipEmoji(for: index))
                    }
                }

                if case .failed(let message) = tipJarManager.purchaseState {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if tipJarManager.purchaseState != .success {
                Button("Dismiss") {
                    withAnimation {
                        DownloadStore.shared.hasDismissedTipJar = true
                        showTipJar = false
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
        .task {
            if tipJarManager.tips.isEmpty {
                await tipJarManager.loadProducts()
            }
        }
    }

    private func tipButton(for product: Product, emoji: String) -> some View {
        Button {
            Task {
                await tipJarManager.purchase(product)
            }
        } label: {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(product.displayPrice)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(tipJarManager.purchaseState == .purchasing)
    }

    private func tipEmoji(for index: Int) -> String {
        switch index {
        case 0: return "🪙"
        case 1: return "☕"
        case 2: return "🍕"
        case 3: return "🎉"
        default: return "💝"
        }
    }
}

#Preview {
    SettingsView()
}
