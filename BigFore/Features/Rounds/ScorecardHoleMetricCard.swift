import SwiftUI

struct ScorecardHoleMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(BigForeDesign.Spacing.medium)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card))
        .accessibilityElement(children: .combine)
    }
}
