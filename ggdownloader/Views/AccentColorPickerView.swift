import SwiftUI

struct AccentColorPickerView: View {
    @State private var accentManager = AccentColorManager.shared
    @State private var customColor: Color = .blue

    private let presets: [(name: String, color: Color)] = [
        ("Blue",   .blue),
        ("Purple", .purple),
        ("Pink",   .pink),
        ("Red",    .red),
        ("Orange", .orange),
        ("Green",  .green),
        ("Teal",   .teal),
        ("Indigo", .indigo),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(presets, id: \.name) { preset in
                    presetCircle(preset.color, name: preset.name)
                }
                customPickerCircle
            }
            .padding(.vertical, 4)
        }
    }

    private func presetCircle(_ color: Color, name: String) -> some View {
        let selected = accentManager.accentColor.hexString == color.hexString
        return Circle()
            .fill(color)
            .frame(width: 32, height: 32)
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(color.opacity(0.4), lineWidth: selected ? 2 : 0)
                    .frame(width: 38, height: 38)
            }
            .onTapGesture {
                accentManager.setColor(color)
            }
            .accessibilityLabel(name)
    }

    private var customPickerCircle: some View {
        let isCustom = !presets.contains(where: {
            $0.color.hexString == accentManager.accentColor.hexString
        })
        return ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    )
                )
                .frame(width: 32, height: 32)
            if isCustom {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            ColorPicker("Custom", selection: $customColor, supportsOpacity: false)
                .labelsHidden()
                .opacity(0.015)
                .frame(width: 32, height: 32)
        }
        .overlay {
            Circle()
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: isCustom ? 2 : 0)
                .frame(width: 38, height: 38)
        }
        .onChange(of: customColor) { _, newColor in
            accentManager.setColor(newColor)
        }
        .accessibilityLabel("Custom color")
    }
}

#Preview {
    Form {
        Section("Appearance") {
            AccentColorPickerView()
        }
    }
}
