import SwiftUI

/// BigFore’s design system: static tokens (`Palette`, `Spacing`, …) and small `View` extensions.
/// There is no separate design-model package—tune visuals here and in feature-specific helpers.
enum BigForeDesign {
    /// Opacity for layered cards on photo backdrops (`bigForeAerialScreenBackground`, scorecard, …).
    enum AerialGlass {
        static let fillLeadingOpacity: Double = 0.34
        static let fillTrailingOpacity: Double = 0.20
        static let strokePrimaryOpacity: Double = 0.20
        /// `PlayStatGrid` tiles sitting on an aerial glass shell.
        static let statTileFillOpacity: Double = 0.14
    }

    /// Dimming and edge treatment for `oldScorecard` full-screen backdrop.
    enum ScorecardBackdrop {
        static func mainDimOpacity(for colorScheme: ColorScheme) -> Double {
            colorScheme == .dark ? 0.52 : 0.48
        }

        private static let vignetteTop: Double = 0.38
        private static let vignetteBottom: Double = 0.48

        static var edgeVignette: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(vignetteTop), location: 0),
                    .init(color: .clear, location: 0.2),
                    .init(color: .clear, location: 0.8),
                    .init(color: .black.opacity(vignetteBottom), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Darker frosted shells on the busy `oldScorecard` photo (only scorecard cards use this).
    enum ScorecardGlass {
        static let cardFillLeadingOpacity: Double = 0.58
        static let cardFillTrailingOpacity: Double = 0.40
        static let strokePrimaryOpacity: Double = 0.30
        static let metricTileFillOpacity: Double = 0.22

        /// Player rows sit on `scorecardCardBackground()`; lighter fill so the stack reads like one panel, not double-tinted black.
        static let nestedCardFillLeadingOpacity: Double = 0.30
        static let nestedCardFillTrailingOpacity: Double = 0.18
        static let nestedStrokePrimaryOpacity: Double = 0.22
    }

    enum Palette {
        static let primaryAction: Color = .green
        static let secondaryAction: Color = .blue
        static let mapPin: Color = .orange
        static let tee: Color = .blue
        static let holePin: Color = .green
        static let shot: Color = .blue
        static let ball: Color = .green
        static let target: Color = .cyan
        static let hazard: Color = .yellow
        static let dogleg: Color = .purple
        static let destructive: Color = .red
        static let distanceLine: Color = .orange
        static let setupLine: Color = .red
        static let transitionLine: Color = .green
        static let shotLine: Color = .blue
    }

    enum Radius {
        static let card: CGFloat = 14
        static let panel: CGFloat = 22
        static let capsulePanel: CGFloat = 17
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
    }

    enum Gradients {
        static let cardFill = LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemGroupedBackground).opacity(0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Translucent panels over photo backdrops (Play, Rounds, discovery rows).
        static let aerialGlassCardFill = LinearGradient(
            colors: [
                Color(.systemBackground).opacity(AerialGlass.fillLeadingOpacity),
                Color(.systemBackground).opacity(AerialGlass.fillTrailingOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Heavier glass so scorecard typography stays legible over handwriting in `oldScorecard`.
        static let scorecardGlassCardFill = LinearGradient(
            colors: [
                Color(.systemBackground).opacity(ScorecardGlass.cardFillLeadingOpacity),
                Color(.systemBackground).opacity(ScorecardGlass.cardFillTrailingOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Inset cards (e.g. per-player rows) on top of `scorecardGlassCardFill` shells.
        static let nestedScorecardGlassCardFill = LinearGradient(
            colors: [
                Color(.systemBackground).opacity(ScorecardGlass.nestedCardFillLeadingOpacity),
                Color(.systemBackground).opacity(ScorecardGlass.nestedCardFillTrailingOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static func softFill(for color: Color) -> LinearGradient {
            LinearGradient(
                colors: [
                    color.opacity(0.22),
                    color.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func strongFill(for color: Color) -> LinearGradient {
            LinearGradient(
                colors: [
                    color,
                    color.opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Gold “selected” / neutral “unselected” pill chrome shared by scorecard toggles and app bordered buttons.
    enum PillButton {
        static let cornerRadius: CGFloat = 8
        static let selectionGlowOpacity: Double = 0.5
        static let selectionGlowRadius: CGFloat = 5
        static let selectionGlowY: CGFloat = 2

        static var selectedGoldGradient: LinearGradient {
            LinearGradient(
                colors: [Color.gpGoldHighlight, Color.gpGold],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Matches `ScorecardNinePageControl` chips when off.
        static var secondaryFill: LinearGradient {
            Gradients.softFill(for: .secondary)
        }

        static func strokeColor(isSelected: Bool) -> Color {
            isSelected ? Color.gpGoldHighlight.opacity(0.95) : Color.secondary.opacity(0.18)
        }

        static func selectionShadow(isSelected: Bool) -> (color: Color, radius: CGFloat, y: CGFloat) {
            guard isSelected else { return (color: .clear, radius: 0, y: 0) }
            return (color: Color.gpGold.opacity(selectionGlowOpacity), radius: selectionGlowRadius, y: selectionGlowY)
        }
    }
}

extension View {
    /// Full-bleed asset + overlay; use for tab roots and scorecard.
    func bigForeLayeredPhotoBackdrop<Dim: View>(imageName: String, @ViewBuilder dim: () -> Dim) -> some View {
        background {
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                dim()
            }
            .ignoresSafeArea()
        }
    }

    /// Full-bleed `aerial` image with the same dim overlay used on Play home.
    func bigForeAerialScreenBackground() -> some View {
        bigForeLayeredPhotoBackdrop(imageName: "aerial") {
            Color.gpArmyGreen.opacity(0.5)
        }
    }

    /// Vintage paper scorecard photography with readable dim and a light edge vignette.
    func bigForeOldScorecardScreenBackground(colorScheme: ColorScheme) -> some View {
        bigForeLayeredPhotoBackdrop(imageName: "oldScorecard") {
            ZStack {
                Color.black.opacity(BigForeDesign.ScorecardBackdrop.mainDimOpacity(for: colorScheme))
                BigForeDesign.ScorecardBackdrop.edgeVignette
            }
        }
    }

    /// Rounded glass card over photo backdrops (Play, Rounds, discovery rows, scorecard).
    func bigForeAerialGlassCardBackground(
        cornerRadius: CGFloat = BigForeDesign.Radius.card,
        dropShadow: Bool = false
    ) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BigForeDesign.Gradients.aerialGlassCardFill)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(BigForeDesign.AerialGlass.strokePrimaryOpacity), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(dropShadow ? 0.16 : 0),
                radius: dropShadow ? 12 : 0,
                y: dropShadow ? 5 : 0
            )
        }
    }

    /// Darker glass tuned for scorecard panels over `oldScorecard`.
    /// - Parameter nestedInScorecardShell: Use lighter fill/stroke when this view sits on another scorecard glass panel (e.g. player rows inside the Scores card).
    func bigForeScorecardGlassCardBackground(
        cornerRadius: CGFloat = BigForeDesign.Radius.panel,
        dropShadow: Bool = true,
        nestedInScorecardShell: Bool = false
    ) -> some View {
        let fill = nestedInScorecardShell
            ? BigForeDesign.Gradients.nestedScorecardGlassCardFill
            : BigForeDesign.Gradients.scorecardGlassCardFill
        let strokeOpacity = nestedInScorecardShell
            ? BigForeDesign.ScorecardGlass.nestedStrokePrimaryOpacity
            : BigForeDesign.ScorecardGlass.strokePrimaryOpacity
        let shadowOpacity = dropShadow ? (nestedInScorecardShell ? 0.10 : 0.22) : 0
        let shadowRadius: CGFloat = nestedInScorecardShell ? 8 : 14
        let shadowY: CGFloat = nestedInScorecardShell ? 3 : 6

        return background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(strokeOpacity), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: dropShadow ? shadowRadius : 0,
                y: dropShadow ? shadowY : 0
            )
        }
    }

    func bigForePanelBackground(
        cornerRadius: CGFloat = BigForeDesign.Radius.panel,
        materialOpacity: Double = 0.76
    ) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial.opacity(materialOpacity))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.background.opacity(0.30))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
