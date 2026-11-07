import SwiftUI
import AppKit

enum Theme {
    static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    static let navy0 = color(0x030712), navy1 = color(0x071230)
    static let navy2 = color(0x0C1B3F), navy3 = color(0x13295A)
    static let ice = color(0xA9C6FF), blue = color(0x3D7BFF)
    static let rec = color(0xFF4D5E), ok = color(0x3DDC97)
    static let recFill = color(0xD62F43) // white text 4.8:1
    static let text = color(0xE8EEFF), mute = color(0x8FA3CC)
    static let amber = color(0xFFD25A)
    static let hairline = ice.opacity(0.14)
}

struct HUDMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct NavyPanel: ViewModifier {
    @Environment(\.displayScale) private var scale
    func body(content: Content) -> some View {
        content.foregroundStyle(Theme.text)
            .background(Theme.navy2.opacity(0.72))
            .background(HUDMaterial())
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1 / scale))
            .environment(\.colorScheme, .dark)
    }
}

struct NavyButton: ButtonStyle {
    var fill: Color = .clear
    var foreground: Color = Theme.text
    var border: Color = .clear
    var selected: Bool? = nil
    var height: CGFloat = 36
    func makeBody(configuration: Configuration) -> some View {
        FocusedButtonLabel(configuration: configuration, fill: fill, foreground: foreground, border: border, selected: selected, height: height)
    }
}

private struct FocusedButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    let foreground: Color
    let border: Color
    let selected: Bool?
    let height: CGFloat
    @Environment(\.isFocused) private var focused
    var body: some View {
        // selected == nil: plain action button. true/false: segment or toggle state.
        let on = selected == true
        configuration.label.lineLimit(1).fixedSize()
            .padding(.horizontal, 10).frame(height: height)
            .foregroundStyle(selected == nil ? foreground : (on ? Color.white : Theme.mute))
            .background(configuration.isPressed ? Theme.ice.opacity(0.28) : (on ? Theme.blue.opacity(0.55) : fill))
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Theme.ice.opacity(0.85) : border, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Theme.ice : .clear, lineWidth: 2))
    }
}

/// Decorative thumbnail border; keyboard focus gets its own high-contrast outline.
struct NavyThumbnail: ViewModifier {
    let selected: Bool
    @Environment(\.isFocused) private var focused
    func body(content: Content) -> some View {
        content
            .background(selected ? Theme.blue.opacity(0.25) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected || focused ? Theme.ice : Theme.hairline,
                              lineWidth: selected || focused ? 2 : 1))
            .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}

struct NavyDivider: View {
    var vertical = false
    @Environment(\.displayScale) private var scale
    var body: some View {
        Rectangle().fill(Theme.hairline)
            .frame(width: vertical ? 1 / scale : nil, height: vertical ? nil : 1 / scale)
            .accessibilityHidden(true)
    }
}

struct NavyOptionPicker: ViewModifier {
    func body(content: Content) -> some View {
        content.pickerStyle(.menu).labelsHidden()
            .buttonStyle(.borderless).foregroundStyle(Theme.text)
            .tint(Theme.text).font(.system(size: 13))
    }
}
