# GGDownloader - Implementation Plan

## Overview

Background file downloader for iOS 26 using SwiftUI + Liquid Glass design, Dynamic Island via Live Activities, and `URLSession` background transfers that survive app suspension/termination.

**Target:** iOS 26.4 | **Xcode:** 26.4 | **Swift:** 5.0 with strict concurrency  
**Bundle ID:** `sanuki.ggdownloader`  
**Team ID:** `S8C9WFT4QV`

---

## Architecture

```
ggdownloader/
├── App/
│   ├── ggdownloaderApp.swift          -- App entry point + UIApplicationDelegateAdaptor
│   └── AppDelegate.swift              -- Handle background URLSession wake events
├── Models/
│   ├── DownloadItem.swift             -- Download model (id, url, filename, state, progress, etc.)
│   └── DownloadAttributes.swift       -- ActivityKit attributes (SHARED with widget target)
├── Services/
│   ├── DownloadManager.swift          -- Core download engine (URLSession background)
│   └── LiveActivityManager.swift      -- Start/update/end Live Activities
├── Views/
│   ├── ContentView.swift              -- Root TabView with Liquid Glass
│   ├── DownloadListView.swift         -- List of active/completed downloads
│   ├── AddDownloadView.swift          -- URL input sheet
│   └── DownloadRowView.swift          -- Single download row with progress
├── Persistence/
│   └── DownloadStore.swift            -- Persist download metadata + resume data to disk
└── Extensions/
    └── ByteCountFormatting.swift      -- File size formatting helpers

ggdownloaderWidgetExtension/
├── DownloadActivityWidget.swift       -- Dynamic Island + Lock Screen Live Activity views
└── DownloadAttributes.swift           -- Same file, shared via target membership
```

---

## Phase 1: Project Setup & Configuration

### Step 1.1: Add Widget Extension Target

In Xcode, add a new target:
- **Type:** Widget Extension
- **Name:** `ggdownloaderWidgetExtension`
- **Include Live Activity:** Yes
- **Bundle ID:** `sanuki.ggdownloader.widgetextension`

This creates the widget extension with `ActivityConfiguration` boilerplate.

### Step 1.2: Info.plist Configuration

Add to main app target's Info.plist (auto-generated, so add via build settings or create Info.plist file):

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

In build settings, set `INFOPLIST_KEY_NSSupportsLiveActivities = YES` for the app target.

### Step 1.3: Background Modes

Enable **Background Modes** capability for the app target. Check:
- **Background fetch**
- **Background processing**

Note: `URLSession` background downloads do NOT require a background mode capability. The system handles them via `nsurlsessiond` daemon. But background fetch is useful for reconnecting sessions.

### Step 1.4: App Group (Optional but Recommended)

Add App Group capability to both app and widget extension targets:
- Group: `group.sanuki.ggdownloader`

This allows sharing data (download state, resume data) between app and widget extension via shared container.

---

## Phase 2: Data Models

### Step 2.1: DownloadItem Model

```swift
// Models/DownloadItem.swift
import Foundation

enum DownloadStatus: String, Codable {
    case waiting
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

struct DownloadItem: Identifiable, Codable {
    let id: UUID
    let url: URL
    let fileName: String
    var status: DownloadStatus
    var progress: Double           // 0.0 - 1.0
    var totalBytes: Int64
    var downloadedBytes: Int64
    var dateAdded: Date
    var dateCompleted: Date?
    var errorMessage: String?
    var taskIdentifier: Int?       // URLSessionTask.taskIdentifier for reconnection
}
```

### Step 2.2: ActivityAttributes (Shared Between Targets)

```swift
// Models/DownloadAttributes.swift
// TARGET MEMBERSHIP: both ggdownloader AND ggdownloaderWidgetExtension
import ActivityKit
import Foundation

struct DownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double
        var bytesDownloaded: Int64
        var totalBytes: Int64
        var statusMessage: String
        var speed: String              // e.g. "12.4 MB/s"
    }

    var fileName: String
    var downloadID: String             // UUID string to correlate with DownloadItem
}
```

---

## Phase 3: Download Engine (Core)

### Step 3.1: DownloadManager

This is the most critical component. Must be:
- A singleton (`@Observable` class)
- Use `URLSessionConfiguration.background(withIdentifier:)` 
- Implement `URLSessionDownloadDelegate` (NOT completion handlers)
- Handle resume data persistence
- Track multiple concurrent downloads
- Update Live Activities on progress

```swift
// Services/DownloadManager.swift
import Foundation
import Observation

@Observable
@MainActor
class DownloadManager: NSObject, Sendable {
    static let shared = DownloadManager()
    
    var downloads: [DownloadItem] = []
    
    private nonisolated(unsafe) var urlSession: URLSession!
    private nonisolated(unsafe) var backgroundCompletionHandler: (() -> Void)?
    
    // Map taskIdentifier -> downloadID for delegate callbacks
    private nonisolated(unsafe) var taskToDownloadID: [Int: UUID] = [:]
    
    override private init() {
        super.init()
        let config = URLSessionConfiguration.background(
            withIdentifier: "\(Bundle.main.bundleIdentifier!).background"
        )
        config.isDiscretionary = false              // Download immediately
        config.sessionSendsLaunchEvents = true      // Wake app on completion
        config.allowsExpensiveNetworkAccess = true   // Allow cellular
        config.allowsConstrainedNetworkAccess = true // Allow low-data mode
        config.httpMaximumConnectionsPerHost = 4
        
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
}
```

**Key implementation details for the delegate:**

```swift
extension DownloadManager: URLSessionDelegate, URLSessionDownloadDelegate {
    
    // REQUIRED: Download finished successfully
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // 1. Determine destination path (Documents directory)
        // 2. Remove existing file at destination if any
        // 3. Move temp file to destination
        // 4. Update DownloadItem status to .completed
        // 5. End Live Activity with success
    }
    
    // Progress updates
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // 1. Calculate progress fraction
        // 2. Calculate download speed (track bytes over time intervals)
        // 3. Update DownloadItem progress
        // 4. Update Live Activity with new progress
        // Throttle updates: update Live Activity at most once per second
    }
    
    // Task completed (success or error)
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return } // Success handled in didFinishDownloadingTo
        
        let nsError = error as NSError
        // Extract resume data from error
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            // Save resume data to disk via DownloadStore
            // Update DownloadItem status to .paused
        } else {
            // Permanent failure
            // Update DownloadItem status to .failed
            // End Live Activity with failure
        }
    }
    
    // All background events delivered
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
```

### Step 3.2: Download Operations

```swift
// Add to DownloadManager
func startDownload(url: URL, fileName: String? = nil) {
    let name = fileName ?? url.lastPathComponent
    let item = DownloadItem(
        id: UUID(),
        url: url,
        fileName: name,
        status: .downloading,
        progress: 0,
        totalBytes: 0,
        downloadedBytes: 0,
        dateAdded: Date()
    )
    downloads.append(item)
    
    let task = urlSession.downloadTask(with: url)
    task.taskDescription = item.id.uuidString   // Tag task with download ID
    taskToDownloadID[task.taskIdentifier] = item.id
    task.resume()
    
    // Start Live Activity
    LiveActivityManager.shared.startActivity(for: item)
    
    // Persist
    DownloadStore.shared.save(downloads)
}

func pauseDownload(id: UUID) {
    // Find the task by id, cancel with resume data
    // task.cancel(byProducingResumeData:)
    // Save resume data, update status to .paused
}

func resumeDownload(id: UUID) {
    // Load resume data from disk
    // Create new task: urlSession.downloadTask(withResumeData: data)
    // Resume task, update status to .downloading
    // Restart Live Activity
}

func cancelDownload(id: UUID) {
    // task.cancel() -- no resume data
    // Update status to .cancelled
    // End Live Activity
    // Delete resume data from disk
}

func reconnectTasks() {
    // Called on app launch to reconnect to any existing background tasks
    urlSession.getAllTasks { tasks in
        for task in tasks {
            // Match tasks to existing DownloadItem via taskDescription (UUID string)
            // Update taskToDownloadID mapping
        }
    }
}
```

### Step 3.3: AppDelegate for Background Session Handling

```swift
// App/AppDelegate.swift
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Store completion handler - DownloadManager will call it
        // when urlSessionDidFinishEvents fires
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
        // Accessing .shared recreates the session with same identifier,
        // which reconnects to the daemon's finished tasks
    }
}
```

Update app entry point:

```swift
// App/ggdownloaderApp.swift
@main
struct ggdownloaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    DownloadManager.shared.reconnectTasks()
                }
        }
    }
}
```

---

## Phase 4: Live Activity Manager

### Step 4.1: LiveActivityManager

```swift
// Services/LiveActivityManager.swift
import ActivityKit
import Foundation

@Observable
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    // Map downloadID -> Activity
    private var activities: [UUID: Activity<DownloadAttributes>] = [:]
    
    func startActivity(for item: DownloadItem) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = DownloadAttributes(
            fileName: item.fileName,
            downloadID: item.id.uuidString
        )
        let initialState = DownloadAttributes.ContentState(
            progress: 0,
            bytesDownloaded: 0,
            totalBytes: item.totalBytes,
            statusMessage: "Starting...",
            speed: "--"
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil)
            )
            activities[item.id] = activity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updateProgress(
        downloadID: UUID,
        progress: Double,
        bytesDownloaded: Int64,
        totalBytes: Int64,
        speed: String
    ) {
        guard let activity = activities[downloadID] else { return }
        
        let state = DownloadAttributes.ContentState(
            progress: progress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            statusMessage: "Downloading...",
            speed: speed
        )
        
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }
    }
    
    func endActivity(downloadID: UUID, success: Bool) {
        guard let activity = activities[downloadID] else { return }
        
        let finalState = DownloadAttributes.ContentState(
            progress: success ? 1.0 : 0,
            bytesDownloaded: 0,
            totalBytes: 0,
            statusMessage: success ? "Download Complete" : "Download Failed",
            speed: "--"
        )
        
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 30) // Dismiss after 30 seconds
            )
            activities.removeValue(forKey: downloadID)
        }
    }
}
```

### Step 4.2: Throttle Live Activity Updates

Live Activities should not update more than once per second. Add throttling in the progress delegate:

```swift
// In DownloadManager
private var lastActivityUpdateTime: [UUID: Date] = [:]

private func throttledActivityUpdate(downloadID: UUID, progress: Double, bytes: Int64, total: Int64, speed: String) {
    let now = Date()
    if let lastUpdate = lastActivityUpdateTime[downloadID],
       now.timeIntervalSince(lastUpdate) < 1.0 {
        return // Skip, too soon
    }
    lastActivityUpdateTime[downloadID] = now
    LiveActivityManager.shared.updateProgress(
        downloadID: downloadID,
        progress: progress,
        bytesDownloaded: bytes,
        totalBytes: total,
        speed: speed
    )
}
```

---

## Phase 5: Widget Extension (Dynamic Island)

### Step 5.1: DownloadActivityWidget

```swift
// ggdownloaderWidgetExtension/DownloadActivityWidget.swift
import SwiftUI
import WidgetKit
import ActivityKit

struct DownloadActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadAttributes.self) { context in
            // ── LOCK SCREEN VIEW ──
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── EXPANDED VIEW ──
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.title2.bold())
                        Text(context.state.speed)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.attributes.fileName)
                            .font(.headline)
                            .lineLimit(1)
                        Gauge(value: context.state.progress) { EmptyView() }
                            .gaugeStyle(.accessoryLinear)
                            .tint(.blue)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(formatBytes(context.state.bytesDownloaded))
                        Text("/")
                        Text(formatBytes(context.state.totalBytes))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            } minimal: {
                Gauge(value: context.state.progress) {
                    Image(systemName: "arrow.down")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.blue)
            }
        }
    }
    
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<DownloadAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
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
            }
            
            Gauge(value: context.state.progress) { EmptyView() }
                .gaugeStyle(.accessoryLinear)
                .tint(.blue)
            
            HStack {
                Text("\(formatBytes(context.state.bytesDownloaded)) / \(formatBytes(context.state.totalBytes))")
                Spacer()
                Text(context.state.speed)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
```

### Step 5.2: Widget Bundle

```swift
// ggdownloaderWidgetExtension/ggdownloaderWidgetBundle.swift
import WidgetKit
import SwiftUI

@main
struct ggdownloaderWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownloadActivityWidget()
    }
}
```

---

## Phase 6: SwiftUI Views with Liquid Glass

### Step 6.1: ContentView (Root TabView)

```swift
// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .downloads
    @State private var showAddSheet = false
    
    enum AppTab: Hashable {
        case downloads
        case completed
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Downloads", systemImage: "arrow.down.circle", value: AppTab.downloads) {
                DownloadListView(filter: .active)
            }
            Tab("Completed", systemImage: "checkmark.circle", value: AppTab.completed) {
                DownloadListView(filter: .completed)
            }
            Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            // Floating "Add Download" button in Liquid Glass
            Button(action: { showAddSheet = true }) {
                Label("Add Download", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddDownloadView()
        }
    }
}
```

**Note on Liquid Glass:** Recompiling with Xcode 26 SDK automatically applies Liquid Glass to standard TabView and NavigationStack chrome. No manual `.glassEffect()` needed for system bars.

### Step 6.2: DownloadListView

```swift
// Views/DownloadListView.swift
import SwiftUI

enum DownloadFilter {
    case active    // .waiting, .downloading, .paused
    case completed // .completed, .failed, .cancelled
}

struct DownloadListView: View {
    let filter: DownloadFilter
    @State private var downloadManager = DownloadManager.shared
    
    var filteredDownloads: [DownloadItem] {
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
            List {
                ForEach(filteredDownloads) { item in
                    DownloadRowView(item: item)
                        .swipeActions(edge: .trailing) {
                            if item.status == .downloading {
                                Button("Pause") {
                                    downloadManager.pauseDownload(id: item.id)
                                }
                                .tint(.orange)
                            }
                            Button("Cancel", role: .destructive) {
                                downloadManager.cancelDownload(id: item.id)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if item.status == .paused || item.status == .failed {
                                Button("Resume") {
                                    downloadManager.resumeDownload(id: item.id)
                                }
                                .tint(.green)
                            }
                        }
                }
            }
            .navigationTitle(filter == .active ? "Downloads" : "Completed")
            .overlay {
                if filteredDownloads.isEmpty {
                    ContentUnavailableView(
                        filter == .active ? "No Active Downloads" : "No Completed Downloads",
                        systemImage: filter == .active ? "arrow.down.circle" : "checkmark.circle",
                        description: Text(filter == .active ? "Add a URL to start downloading" : "Completed downloads will appear here")
                    )
                }
            }
        }
    }
}
```

### Step 6.3: DownloadRowView

```swift
// Views/DownloadRowView.swift
import SwiftUI

struct DownloadRowView: View {
    let item: DownloadItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                statusBadge
            }
            
            if item.status == .downloading {
                Gauge(value: item.progress) { EmptyView() }
                    .gaugeStyle(.accessoryLinear)
                    .tint(.blue)
                
                HStack {
                    Text(ByteCountFormatter.string(
                        fromByteCount: item.downloadedBytes, countStyle: .file
                    ))
                    Text("/")
                    Text(ByteCountFormatter.string(
                        fromByteCount: item.totalBytes, countStyle: .file
                    ))
                    Spacer()
                    Text("\(Int(item.progress * 100))%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            if item.status == .failed, let error = item.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch item.status {
        case .waiting: "clock"
        case .downloading: "arrow.down.circle.fill"
        case .paused: "pause.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "xmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch item.status {
        case .waiting: .gray
        case .downloading: .blue
        case .paused: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: .gray
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        Text(item.status.rawValue.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(iconColor.opacity(0.15), in: Capsule())
    }
}
```

### Step 6.4: AddDownloadView

```swift
// Views/AddDownloadView.swift
import SwiftUI

struct AddDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var fileName = ""
    @State private var isValidURL = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Download URL") {
                    TextField("https://example.com/file.zip", text: $urlString)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: urlString) { _, newValue in
                            isValidURL = URL(string: newValue)?.scheme?.hasPrefix("http") == true
                            if fileName.isEmpty, let url = URL(string: newValue) {
                                fileName = url.lastPathComponent
                            }
                        }
                }
                
                Section("File Name (Optional)") {
                    TextField("Auto-detected from URL", text: $fileName)
                }
            }
            .navigationTitle("Add Download")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") {
                        guard let url = URL(string: urlString) else { return }
                        DownloadManager.shared.startDownload(
                            url: url,
                            fileName: fileName.isEmpty ? nil : fileName
                        )
                        dismiss()
                    }
                    .disabled(!isValidURL)
                }
            }
        }
    }
}
```

### Step 6.5: Custom Liquid Glass Floating Action Button (Optional Enhancement)

For a custom glass-styled FAB instead of tab accessory:

```swift
// Example: Floating glass button overlay
Button(action: { showAddSheet = true }) {
    Image(systemName: "plus")
        .font(.title2)
        .padding()
}
.glassEffect(.regular.interactive(), in: .circle)
```

---

## Phase 7: Persistence Layer

### Step 7.1: DownloadStore

```swift
// Persistence/DownloadStore.swift
import Foundation

class DownloadStore {
    static let shared = DownloadStore()
    
    private let downloadsKey = "downloads"
    private let resumeDataDirectory: URL
    private let fileManager = FileManager.default
    
    private init() {
        // Use app group container if sharing with widget, else documents
        let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.sanuki.ggdownloader"
        ) ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        resumeDataDirectory = container.appendingPathComponent("ResumeData")
        try? fileManager.createDirectory(at: resumeDataDirectory, withIntermediateDirectories: true)
    }
    
    // ── Download Items ──
    
    func save(_ downloads: [DownloadItem]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(downloads) {
            UserDefaults(suiteName: "group.sanuki.ggdownloader")?.set(data, forKey: downloadsKey)
        }
    }
    
    func load() -> [DownloadItem] {
        guard let data = UserDefaults(suiteName: "group.sanuki.ggdownloader")?.data(forKey: downloadsKey),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data)
        else { return [] }
        return items
    }
    
    // ── Resume Data ──
    
    func saveResumeData(_ data: Data, for downloadID: UUID) {
        let url = resumeDataDirectory.appendingPathComponent(downloadID.uuidString)
        try? data.write(to: url)
    }
    
    func loadResumeData(for downloadID: UUID) -> Data? {
        let url = resumeDataDirectory.appendingPathComponent(downloadID.uuidString)
        return try? Data(contentsOf: url)
    }
    
    func deleteResumeData(for downloadID: UUID) {
        let url = resumeDataDirectory.appendingPathComponent(downloadID.uuidString)
        try? fileManager.removeItem(at: url)
    }
}
```

---

## Phase 8: Settings View

```swift
// Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("maxConcurrentDownloads") private var maxConcurrent = 3
    @AppStorage("allowCellular") private var allowCellular = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Downloads") {
                    Stepper("Max concurrent: \(maxConcurrent)", value: $maxConcurrent, in: 1...5)
                    Toggle("Allow cellular downloads", isOn: $allowCellular)
                }
                
                Section("Storage") {
                    // Show downloaded files size, clear completed, etc.
                    Button("Clear Completed Downloads") {
                        DownloadManager.shared.clearCompleted()
                    }
                }
                
                Section("About") {
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

---

## Implementation Order (For Executing Agent)

Execute in this exact order. Each step should compile before moving to next.

### Round 1: Foundation (Must compile and run)
1. Create `Models/DownloadItem.swift`
2. Create `Models/DownloadAttributes.swift`
3. Create `Persistence/DownloadStore.swift`
4. Create `Extensions/ByteCountFormatting.swift` (simple helper)

### Round 2: Download Engine
5. Create `Services/DownloadManager.swift` with full delegate implementation
6. Create `Services/LiveActivityManager.swift`
7. Create `App/AppDelegate.swift`
8. Update `App/ggdownloaderApp.swift` with UIApplicationDelegateAdaptor

### Round 3: UI
9. Create `Views/DownloadRowView.swift`
10. Create `Views/DownloadListView.swift`
11. Create `Views/AddDownloadView.swift`
12. Create `Views/SettingsView.swift`
13. Update `Views/ContentView.swift` with TabView + Liquid Glass

### Round 4: Widget Extension
14. Create widget extension target (requires Xcode - agent should create files, user adds target)
15. Create `ggdownloaderWidgetExtension/DownloadActivityWidget.swift`
16. Create `ggdownloaderWidgetExtension/ggdownloaderWidgetBundle.swift`
17. Ensure `DownloadAttributes.swift` has membership in both targets

### Round 5: Polish
18. Add Info.plist key `NSSupportsLiveActivities = YES`
19. Test background download with a large file URL
20. Test pause/resume flow
21. Test app kill + background completion
22. Test Dynamic Island compact and expanded views

---

## Critical Implementation Notes

### Background Download Gotchas
- **NEVER use async/await completion handlers** with background URLSession. Only delegate pattern works.
- The background session identifier must be **identical** across app launches. Use `Bundle.main.bundleIdentifier! + ".background"`.
- When app relaunches after termination, you must recreate `URLSession` with same identifier to reconnect.
- The temporary file in `didFinishDownloadingTo` is deleted **immediately** after the delegate method returns. Move it synchronously.
- `isDiscretionary = false` is critical for user-initiated downloads. When `true`, system may delay downloads.

### Live Activity Gotchas
- Max 8 hour lifetime per Live Activity
- Update frequency: system may throttle updates. Keep to ~1/second max.
- `DownloadAttributes.swift` MUST be in both target memberships or widget won't compile
- Check `ActivityAuthorizationInfo().areActivitiesEnabled` before requesting

### Concurrency Notes
- Project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- DownloadManager delegates run on background queue. Use `@MainActor` dispatch for UI updates.
- Mark delegate methods as `nonisolated` since URLSession calls them on its own queue.

### Liquid Glass Notes
- Standard SwiftUI components (TabView, NavigationStack bars, toolbars) get glass automatically when compiled with iOS 26 SDK
- Use `.glassEffect()` modifier only for custom floating UI elements
- Use `.glassEffect(.regular.interactive())` for tappable custom glass elements
- Wrap nearby glass elements in `GlassEffectContainer` for proper morphing

### File Storage
- Downloaded files go to Documents directory (user-visible in Files app)
- Resume data stored in App Group container
- Download metadata stored in App Group UserDefaults (shared with widget if needed)
