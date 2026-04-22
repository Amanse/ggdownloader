# GGDownloader

<a href="https://www.buymeacoffee.com/sanuki" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

Background file downloader for iOS 26. Downloads survive app suspension, device sleep, and process termination. Full Dynamic Island integration via Live Activities.

## Features

- **True background downloads** — system daemon (`nsurlsessiond`) handles transfers. App can be killed; downloads complete anyway.
- **Resumable downloads** — pause, cancel with resume data. Resumes from byte offset (server must support HTTP Range).
- **Dynamic Island** — compact, expanded, and minimal Live Activity views showing real-time progress, speed, and byte counts.
- **Lock Screen widget** — same Live Activity surfaces on Lock Screen with progress gauge.
- **Liquid Glass UI** — native iOS 26 design. Tab bar, navigation bars, and bottom accessory use system glass automatically.
- **Multiple concurrent downloads** — up to 4 connections per host.
- **Speed tracking** — exponential moving average for smooth MB/s display.
- **Persistent state** — downloads survive app restart. Reconnects to in-flight tasks on launch.

## Requirements

- iOS 26.4+
- Xcode 26.4+
- Device with Dynamic Island (iPhone 14 Pro or later) for Live Activity compact/minimal views

## Architecture

```
ggdownloader/
├── App/
│   └── AppDelegate.swift              UIApplicationDelegate for background session wake
├── Models/
│   ├── DownloadItem.swift             Download model + DownloadStatus enum
│   └── DownloadAttributes.swift       ActivityKit attributes (app target copy)
├── Services/
│   ├── DownloadManager.swift          URLSession background engine + all delegates
│   └── LiveActivityManager.swift      ActivityKit start/update/end with 1s throttle
├── Persistence/
│   └── DownloadStore.swift            JSON persistence + resume data + App Group
├── Extensions/
│   └── ByteCountFormatting.swift      File size and speed formatting
├── Views/
│   ├── ContentView.swift              Root TabView with .tabBarMinimizeBehavior
│   ├── DownloadListView.swift         Active / Completed lists with swipe actions
│   ├── DownloadRowView.swift          Row with progress bar and status badge
│   ├── AddDownloadView.swift          URL input sheet with clipboard paste
│   └── SettingsView.swift             Storage stats and clear action
└── ggdownloaderApp.swift              @main + UIApplicationDelegateAdaptor

ggdownloaderWidgetExtension/
├── DownloadAttributes.swift           ActivityKit attributes (widget target copy)
├── DownloadActivityWidget.swift       Dynamic Island + Lock Screen Live Activity
└── ggdownloaderWidgetBundle.swift     @main widget bundle
```

## How Background Downloads Work

1. App creates a `URLSessionDownloadTask` on a `URLSessionConfiguration.background` session.
2. App is suspended or killed — the system `nsurlsessiond` daemon continues the transfer.
3. On completion, the system relaunches the app in the background.
4. `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)` fires.
5. `DownloadManager.shared` is accessed — recreating the session with the same identifier reconnects to completed tasks.
6. Delegate callbacks fire (`didFinishDownloadingTo`, `didCompleteWithError`).
7. `urlSessionDidFinishEvents(forBackgroundURLSession:)` fires; stored completion handler is called.

The downloaded file at the temporary `location` URL in `didFinishDownloadingTo` **must be moved synchronously** before the method returns — the system deletes it immediately after.

## Resume Data

Pause stores `NSURLSessionDownloadTaskResumeData` from the error info or `cancel(byProducingResumeData:)` to the App Group container. Resume creates a new task via `urlSession.downloadTask(withResumeData:)`. Server must respond to `Range` requests for resume to work.

## Setup Notes

- App Group `group.sanuki.ggdownloader` must be enabled on both targets for shared persistence.
- `NSSupportsLiveActivities = YES` must be set in the app target's Info.plist.
- The widget extension target must include `ActivityKit` and `WidgetKit` frameworks.

## Icon

Three variants (light, dark, tinted) generated with AppKit/CoreGraphics — a bold download arrow on a deep navy background with blue-to-cyan gradient fill and specular highlight.
