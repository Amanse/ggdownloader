import SwiftUI

enum DownloadFilter {
    case active
    case completed
}

struct DownloadListView: View {
    let filter: DownloadFilter
    @State private var downloadManager = DownloadManager.shared
    @State private var showAddSheet = false

    private var filteredDownloads: [DownloadItem] {
        switch filter {
        case .active:
            return downloadManager.downloads.filter {
                [.waiting, .downloading, .paused].contains($0.status)
            }
        case .completed:
            return downloadManager.downloads.filter {
                [.completed, .failed, .cancelled].contains($0.status)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredDownloads.isEmpty {
                    emptyState
                } else {
                    downloadList
                }
            }
            .navigationTitle(filter == .active ? "Downloads" : "Completed")
            .toolbar {
                if filter == .active {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showAddSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                } else if !filteredDownloads.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear All", role: .destructive) {
                            withAnimation {
                                downloadManager.clearCompleted()
                            }
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddDownloadView()
            }
        }
    }

    private var downloadList: some View {
        List {
            ForEach(filteredDownloads) { item in
                DownloadRowView(item: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Cancel", role: .destructive) {
                            withAnimation {
                                downloadManager.cancelDownload(id: item.id)
                            }
                        }
                        if item.status == .downloading {
                            Button("Pause") {
                                downloadManager.pauseDownload(id: item.id)
                            }
                            .tint(.orange)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if item.status == .paused || item.status == .failed {
                            Button("Resume") {
                                downloadManager.resumeDownload(id: item.id)
                            }
                            .tint(.green)
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: filteredDownloads.map(\.id))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                filter == .active ? "No Active Downloads" : "No Completed Downloads",
                systemImage: filter == .active ? "arrow.down.circle" : "checkmark.circle"
            )
        } description: {
            Text(
                filter == .active
                    ? "Tap + to add a download URL"
                    : "Completed downloads appear here"
            )
        } actions: {
            if filter == .active {
                Button("Add Download") { showAddSheet = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    DownloadListView(filter: .active)
}
