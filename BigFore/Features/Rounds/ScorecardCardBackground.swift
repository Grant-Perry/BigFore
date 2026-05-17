import SwiftUI

extension View {
    /// Full-screen `oldScorecard` art with dim + vignette (portrait and landscape scorecard).
    func scorecardScreenBackground(colorScheme: ColorScheme) -> some View {
        bigForeOldScorecardScreenBackground(colorScheme: colorScheme)
    }

    /// Darker frosted shells for scorecard only (`ScorecardGlass` tokens).
    func scorecardCardBackground() -> some View {
        bigForeScorecardGlassCardBackground(cornerRadius: BigForeDesign.Radius.panel, dropShadow: true)
            .clipShape(RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel, style: .continuous))
    }
}
