import SwiftUI

/// The app's visual vocabulary.
///
/// Everything on screen is drawn from these tokens: a warm paper ground, deep
/// ink text, hairline rules, and one restrained accent used sparingly. No
/// screen relies on the system's default control tinting or grouped-list
/// chrome, so the phone and the watch read as the same printed object.
enum Theme {

    // MARK: - Palette

    /// The page itself.
    static let paper = adaptive(light: 0xFAF7F1, dark: 0x111110)
    /// Fields, sheets, and anything that sits on top of the page.
    static let card = adaptive(light: 0xFFFDF9, dark: 0x1B1917)
    /// Body text — the poem, titles, anything you actually read.
    static let ink = adaptive(light: 0x1B1815, dark: 0xEDE7DD)
    /// Authors, captions, supporting text.
    static let inkSoft = adaptive(light: 0x6A635A, dark: 0x9B9488)
    /// Line numbers, placeholders, the quietest marks on the page.
    static let inkFaint = adaptive(light: 0xA79F92, dark: 0x6B655C)
    /// Hairline rules. Never a full-weight divider.
    static let rule = adaptive(light: 0xE3DCCF, dark: 0x2C2926)
    /// Used sparingly: the line you're on, an active mode, destructive intent.
    static let accent = adaptive(light: 0x8A3F31, dark: 0xC97C64)
    /// The bar drawn over a line that hasn't been revealed yet.
    static let redaction = adaptive(light: 0x1B1815, dark: 0x38342F)

    // MARK: - Type
    //
    // Poems are set in a serif; everything the app says about a poem is set in
    // small tracked capitals so the two never compete.

    /// The poem's own voice: titles and lines.
    static func serif(_ style: Font.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif).weight(weight)
    }

    /// The same voice at an explicit size, for the one thing whose size isn't
    /// ours to choose: the poem itself, which the reader sets in Settings.
    static func serif(size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, design: .serif).weight(weight)
    }

    /// The app's voice: labels, controls, metadata.
    static func label(_ style: Font.TextStyle = .caption2, _ weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .default).weight(weight)
    }

    /// The text style verse follows for Dynamic Type, and the size it is set
    /// at when the system's text size is the default one. Both differ by how
    /// far the page is from your eye.
    #if os(watchOS)
    static let verseStyle = Font.TextStyle.body
    static let verseSize: CGFloat = 16
    #else
    static let verseStyle = Font.TextStyle.title3
    static let verseSize: CGFloat = 20
    #endif

    /// The size the line-number margin is set at, at that same default.
    static let verseNumberSize: CGFloat = 11

    // MARK: - Metrics

    /// The page margin used by every screen.
    #if os(watchOS)
    static let margin: CGFloat = 4
    static let lineGap: CGFloat = 7
    /// Width of the line-number gutter when line numbers are shown.
    static let gutter: CGFloat = 16
    static let buttonPadding = (vertical: CGFloat(7), horizontal: CGFloat(12))
    #else
    static let margin: CGFloat = 24
    static let lineGap: CGFloat = 12
    static let gutter: CGFloat = 26
    static let buttonPadding = (vertical: CGFloat(13), horizontal: CGFloat(22))
    #endif

    // MARK: - Colour plumbing

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if os(iOS)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
        #else
        // The watch is always dark; it needs no light variant.
        return Color(hex: dark)
        #endif
    }
}

extension Color {
    /// Build a colour from a 24-bit `0xRRGGBB` literal.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

#if os(iOS)
extension UIColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
#endif

// MARK: - Building blocks

/// A true one-pixel rule. The app never uses a full-weight `Divider`.
struct Hairline: View {
    var color: Color = Theme.rule
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / max(displayScale, 1))
    }
}

/// Small tracked capitals — the app's label voice.
private struct SectionLabelModifier: ViewModifier {
    var color: Color

    func body(content: Content) -> some View {
        content
            .font(Theme.label())
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension View {
    /// Styles text as a small tracked capital label.
    func sectionLabel(_ color: Color = Theme.inkFaint) -> some View {
        modifier(SectionLabelModifier(color: color))
    }

    /// Puts the paper ground behind a screen and hides the system's own.
    func paperBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}

// MARK: - Controls

/// The one loud element on a screen: solid ink, paper lettering, square edges.
struct InkButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(.footnote, .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.paper)
            .padding(.vertical, Theme.buttonPadding.vertical)
            .padding(.horizontal, Theme.buttonPadding.horizontal)
            .background(Theme.ink.opacity(isEnabled ? 1 : 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// A text-only button: tracked capitals, no chrome, no tint.
struct QuietButtonStyle: ButtonStyle {
    var color: Color = Theme.inkSoft

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(.footnote, .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.vertical, 8)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}

/// An outlined button, for the second choice in a pair.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(.footnote, .semibold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ink)
            .padding(.vertical, Theme.buttonPadding.vertical - 1)
            .padding(.horizontal, Theme.buttonPadding.horizontal - 2)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Theme.rule, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}
