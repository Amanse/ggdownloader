import SwiftUI
import WidgetKit
import Observation

@Observable
@MainActor
final class AccentColorManager {
    static let shared = AccentColorManager()

    var accentColor: Color = .blue

    private let store = DownloadStore.shared

    private init() {
        accentColor = Color(hex: store.loadAccentColorHex())
    }

    func setColor(_ color: Color) {
        accentColor = color
        store.saveAccentColor(color.hexString)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
