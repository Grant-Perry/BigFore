import SwiftUI

struct ScorecardGridMetricText: View {
    let text: String
    var weight: Font.Weight = .regular

    var body: some View {
        Text(text)
            .font(.caption2.weight(weight))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .frame(height: ScorecardGridMetrics.metricRowHeight)
    }
}
