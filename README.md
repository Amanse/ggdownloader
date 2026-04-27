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

## Sideloading (Feather, AltStore, Sideloadly, etc.)

If you build the IPA yourself and sideload with your own developer certificate (not the original team `S8C9WFT4QV`), the app group **`group.sanuki.ggdownloader`** is not signable by your cert and the app will fail to start downloads with:

> Couldn't create file

This is `NSURLErrorCannotCreateFile` (`-3000`). The background URL session daemon (`nsurlsessiond`) can't create the partial download in the app's cache because the entitlements declared in the bundle (`com.apple.security.application-groups`) don't match what your signing identity is authorized to grant. iOS responds by tightening the sandbox and blocking file creation.

Xcode debug builds work because the original team profile grants the App Group; your re-signed IPA does not.

### Fix when sideloading

You have two options. Pick one **before** signing/installing the IPA:

**Option A — Remove the App Group entitlement (easiest, recommended for free Apple IDs)**

In Feather, before installing:

1. Long-press the IPA in your library → **Signing Options** (or *App Options* / *Modify* depending on Feather version).
2. Disable / remove **App Groups** (toggle off `group.sanuki.ggdownloader`).
3. Sign and install.

In other sideloaders:

- **AltStore / SideStore**: open the app's settings and toggle off App Groups before installing.
- **Sideloadly**: under *Advanced options*, check "Remove app groups" (or manually edit the `.entitlements` to delete the `application-groups` key) before signing.

Trade-off: with the App Group removed, the **Share Extension and Lock Screen widget can't hand URLs to the main app**, so adding downloads via the iOS share sheet won't work. Downloads added from inside the app work normally. Live Activities in the Dynamic Island still work.

**Option B — Replace the App Group ID with one your team owns (paid Apple Developer account)**

1. In Apple Developer portal, register a new app group, e.g. `group.<your-team>.ggdownloader`.
2. In Xcode, edit `ggdownloader.entitlements`, `ggdownloaderShareExtension.entitlements`, and `ggdownloaderWidgetExtensionExtension.entitlements` and replace `group.sanuki.ggdownloader` with your group ID.
3. In `ggdownloader/Persistence/DownloadStore.swift` and `ggdownloaderShareExtension/ShareViewController.swift`, replace the `appGroupID` constant with your group ID.
4. Set `DEVELOPMENT_TEAM` to your team ID and rebuild.

Everything (including the Share Extension) works normally with this option.

### Other tips

- **TrollStore** users: no re-signing happens, so this issue doesn't apply — install the IPA as-is.
- After changing signing options in Feather, fully delete the previously installed copy before reinstalling. Stale `nsurlsessiond` cache state from the old install can keep producing the same error otherwise.
- If you still see `Couldn't create file` after removing App Groups, delete the app, reboot the device, and reinstall — this clears any leftover daemon state for the prior bundle ID.

## Icon

Three variants (light, dark, tinted) generated with AppKit/CoreGraphics — a bold download arrow on a deep navy background with blue-to-cyan gradient fill and specular highlight.
