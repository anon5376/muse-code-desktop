// Theme: the Signal Desk palette tokens and shared flat controls.
import SwiftUI
import AppKit

/// Design tokens for the flat charcoal workspace ("Signal Desk").
///
/// Filled native controls draw with light labels supplied by macOS, so they
/// use the deeper `controlAccent` instead of `accent`. Semantic colors beyond
/// this palette should not appear without a DESIGN.md entry.
enum MuseTheme {
    // Muse blue in a neutral native workspace. Filled native controls need a
    // deeper blue because macOS supplies light labels for those controls.
    static let canvas = Color(hex: 0x111112)
    static let sidebar = Color(hex: 0x0C0D0F)
    static let raised = Color(hex: 0x1A1B1E)
    static let popover = Color(hex: 0x232428)
    static let line = Color(hex: 0x26282C)
    static let stroke = Color(hex: 0x3A3D42)
    static let text = Color(hex: 0xE6E8EB)
    static let secondary = Color(hex: 0xA9AEB5)
    static let muted = Color(hex: 0x9CA3AF)
    static let accent = Color(hex: 0x2694FE)
    static let controlAccent = Color(hex: 0x0B5CAE)
    static let attention = Color(hex: 0xF5B54A)
    static let ink = Color(hex: 0x0A1317)
    static let success = Color(hex: 0x7FD88F)
    static let error = Color(hex: 0xFFB2B8)
}

extension Color {
    /// Opaque sRGB color from a packed 0xRRGGBB literal.
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

/// The Muse logo rendered from the bundled SVG at a fixed point size.
/// The mark is decorative; it is hidden from accessibility.
struct MuseMark: View {
    var size: CGFloat = 24
    private static let logo: NSImage = {
        let resources = Bundle.main.url(forResource: "MuseNative_MuseDesktop", withExtension: "bundle")
            .flatMap { Bundle(url: $0) } ?? Bundle.module
        guard let url = resources.url(forResource: "MuseLogo", withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { preconditionFailure("Muse logo resource is missing") }
        return image
    }()

    var body: some View {
        Image(nsImage: Self.logo)
        .resizable().scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A flat toolbar icon button with hover/selection fill and tooltip.
struct IconButton: View {
    let symbol: String
    let label: String
    var selected = false
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? MuseTheme.accent : MuseTheme.secondary)
                .frame(width: 30, height: 30)
                .background(hovered || selected ? MuseTheme.raised : .clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(label).accessibilityLabel(label)
    }
}

/// A 1pt divider in `MuseTheme.line`; the only separator the design uses.
struct Hairline: View {
    var body: some View { Rectangle().fill(MuseTheme.line).frame(height: 1) }
}
