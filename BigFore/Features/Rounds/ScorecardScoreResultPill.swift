import SwiftUI

struct ScorecardScoreResultPill: View {
    let result: ScorecardScoreResult?
    let fallbackText: String

    private var displayTitle: String {
        result?.title ?? fallbackText
    }

    var body: some View {
        Group {
            if result == .doubleBogey || result == .triple {
                Text(displayTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.75)
            } else {
                Label {
                    Text(displayTitle)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.6)
                } icon: {
                    Image(systemName: result?.systemImage ?? "minus.circle")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(result?.tint ?? .secondary)
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.xSmall)
        .background((result?.tint ?? Color.secondary).opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
