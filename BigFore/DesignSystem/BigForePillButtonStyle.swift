import SwiftUI

// MARK: - BigForePillButtonStyle

/// Scorecard-style pill buttons: gold + glow for primary / “on”, soft secondary fill otherwise (`ScorecardNinePageControl`, tee chips).
struct BigForePillButtonStyle: ButtonStyle {
    enum Variant: Sendable {
        case primary
        case secondary
        case destructive
        case toggle(isSelected: Bool)
    }

    enum Metrics: Sendable {
        case standard
        /// No extra padding — background hugs the label (e.g. scorecard tee chips with a fixed frame).
        case chip
    }

    var variant: Variant
    var metrics: Metrics

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    init(variant: Variant, metrics: Metrics = .standard) {
        self.variant = variant
        self.metrics = metrics
    }

    static var bigForePrimary: BigForePillButtonStyle { BigForePillButtonStyle(variant: .primary) }
    static var bigForeSecondary: BigForePillButtonStyle { BigForePillButtonStyle(variant: .secondary) }
    static var bigForeDestructive: BigForePillButtonStyle { BigForePillButtonStyle(variant: .destructive) }
    static func bigForeToggle(isSelected: Bool, metrics: Metrics = .standard) -> BigForePillButtonStyle {
        BigForePillButtonStyle(variant: .toggle(isSelected: isSelected), metrics: metrics)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.48)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                RoundedRectangle(cornerRadius: BigForeDesign.PillButton.cornerRadius, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: BigForeDesign.PillButton.cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }

    private var usesGoldChrome: Bool {
        switch variant {
        case .primary, .toggle(true): true
        case .secondary, .destructive, .toggle(false): false
        }
    }

    private var shadow: (color: Color, radius: CGFloat, y: CGFloat) {
        BigForeDesign.PillButton.selectionShadow(isSelected: usesGoldChrome)
    }

    private var foreground: Color {
        switch variant {
        case .destructive:
            .white
        case .primary, .toggle(true):
            Color.black.opacity(0.82)
        case .secondary, .toggle(false):
            Color.primary
        }
    }

    private var fill: LinearGradient {
        switch variant {
        case .primary, .toggle(true):
            BigForeDesign.PillButton.selectedGoldGradient
        case .secondary, .toggle(false):
            BigForeDesign.PillButton.secondaryFill
        case .destructive:
            BigForeDesign.Gradients.strongFill(for: BigForeDesign.Palette.destructive)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .destructive:
            Color.white.opacity(0.28)
        default:
            BigForeDesign.PillButton.strokeColor(isSelected: usesGoldChrome)
        }
    }

    private var borderWidth: CGFloat { usesGoldChrome ? 1.25 : 1 }

    private var horizontalPadding: CGFloat {
        if metrics == .chip { return 0 }
        switch controlSize {
        case .mini: return 6
        case .small: return 10
        case .regular: return 12
        case .large: return 16
        case .extraLarge: return 20
        @unknown default: return 12
        }
    }

    private var verticalPadding: CGFloat {
        if metrics == .chip { return 0 }
        switch controlSize {
        case .mini: return 3
        case .small: return 5
        case .regular: return 6
        case .large: return 10
        case .extraLarge: return 12
        @unknown default: return 6
        }
    }
}
