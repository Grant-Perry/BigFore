import SwiftUI

struct ScorecardScoreResultPill: View {
    let result: ScorecardScoreResult?
    let fallbackText: String

    var body: some View {
        Label {
            Text(result?.title ?? fallbackText)
        } icon: {
            Image(systemName: result?.systemImage ?? "minus.circle")
        }
        .font(.caption)
        .foregroundStyle(result?.tint ?? .secondary)
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.xSmall)
        .background((result?.tint ?? Color.secondary).opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
