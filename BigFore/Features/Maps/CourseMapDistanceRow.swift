import SwiftUI

struct CourseMapDistanceRow: View {
    let title: String
    let value: String
    var isPrimary = false

    var body: some View {
        LabeledContent {
            Text(value)
                .font(isPrimary ? .title3.weight(.black) : .headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isPrimary ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } label: {
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
