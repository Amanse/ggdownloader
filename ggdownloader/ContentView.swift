import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .downloads
    @State private var showAddSheet = false
    @State private var downloadManager = DownloadManager.shared

    enum AppTab: Hashable {
        case downloads
        case completed
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Downloads", systemImage: "arrow.down.circle.fill", value: AppTab.downloads) {
                DownloadListView(filter: .active)
            }
            Tab("Completed", systemImage: "checkmark.circle.fill", value: AppTab.completed) {
                DownloadListView(filter: .completed)
            }
            Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            Button(action: { showAddSheet = true }) {
                Label("Add Download", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .sheet(isPresented: $showAddSheet) {
            AddDownloadView()
        }
        .alert(
            item: Binding(
                get: { downloadManager.recentFailure },
                set: { _ in downloadManager.recentFailure = nil }
            )
        ) { failure in
            Alert(
                title: Text("Download Failed"),
                message: Text("\(failure.fileName)\n\n\(failure.message)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    ContentView()
}
