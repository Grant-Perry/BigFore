import SwiftUI

struct ScorecardGridRowLabelText: View {
    let text: String
    let height: CGFloat

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(height: height, alignment: .center)
    }
}
