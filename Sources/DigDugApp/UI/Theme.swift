import MarkdownUI
import SwiftUI

/// Committed-dark design tokens for DigDug. One accent (amber → ember) carries
/// the user's voice, primary actions, and active state; everything else is a
/// quiet neutral ramp tuned for code-heavy model output.
enum Palette {
    static let bg = Color(red: 0.067, green: 0.071, blue: 0.086)        // #111216 window
    static let surface = Color(red: 0.114, green: 0.122, blue: 0.145)   // #1D1F25 assistant bubble
    static let codeBg = Color(red: 0.043, green: 0.047, blue: 0.059)    // #0B0C0F editor block
    static let ink = Color(red: 0.929, green: 0.933, blue: 0.953)       // #EDEEF3 primary text
    static let inkDim = Color(red: 0.620, green: 0.635, blue: 0.694)    // #9EA2B1 secondary
    static let accent = Color(red: 0.961, green: 0.620, blue: 0.137)    // #F59E23 amber
    static let accentDeep = Color(red: 0.886, green: 0.337, blue: 0.157) // #E25628 ember
    static let border = Color.white.opacity(0.075)
    static let online = Color(red: 0.31, green: 0.82, blue: 0.51)       // ready indicator
    static let danger = Color(red: 0.94, green: 0.31, blue: 0.29)       // destructive action

    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static var accentSoft: Color { accent.opacity(0.16) }
}

/// Shared corner radii and type sizes so the surface stays consistent.
enum Metrics {
    static let bubbleRadius: CGFloat = 14
    static let codeRadius: CGFloat = 10
    static let bodySize: CGFloat = 15
}

extension Theme {
    /// Markdown styling tuned for dark chat bubbles: large readable body,
    /// amber inline code, and an editor-grade code block.
    @MainActor static let digDug = Theme()
        .text {
            ForegroundColor(Palette.ink)
            FontSize(Metrics.bodySize)
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(Palette.accent)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(13.5)
            ForegroundColor(Palette.accent)
            BackgroundColor(Palette.accentSoft)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(13)
                    ForegroundColor(Palette.ink)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.codeBg)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.codeRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.codeRadius, style: .continuous)
                        .strokeBorder(Palette.border)
                )
                .markdownMargin(top: 8, bottom: 8)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(21)
                    FontWeight(.bold)
                    ForegroundColor(Palette.ink)
                }
                .markdownMargin(top: 14, bottom: 6)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(17)
                    FontWeight(.semibold)
                    ForegroundColor(Palette.ink)
                }
                .markdownMargin(top: 12, bottom: 4)
        }
        .blockquote { configuration in
            configuration.label
                .markdownTextStyle {
                    FontStyle(.italic)
                    ForegroundColor(Palette.inkDim)
                }
                .padding(10)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .markdownMargin(top: 6, bottom: 6)
        }
}
