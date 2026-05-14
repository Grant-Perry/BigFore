import SwiftUI

struct CourseMapShotSummaryList: View {
    let viewModel: CourseMapViewModel

    var body: some View {
        if viewModel.shotSummaries.isEmpty == false {
            VStack(spacing: BigForeDesign.Spacing.small) {
                ForEach(viewModel.shotSummaries) { summary in
                    Button {
                        viewModel.selectShotMarker(id: summary.id)
                    } label: {
                        shotCard(summary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select shot \(summary.shotNumber)")
                }
            }
        }
    }

    private func shotCard(_ summary: CourseMapShotSummary) -> some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
            HStack {
                Text("Shot \(summary.shotNumber)")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(summary.distanceFromPreviousText)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }

            Text(summary.shotNumber == 1 ? "From tee/start" : "From previous ball")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let distanceToPinText = summary.distanceToPinText {
                Text("To pin: \(distanceToPinText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Set the pin to show distance to hole.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(BigForeDesign.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        .overlay {
            if summary.isSelected {
                RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                    .stroke(BigForeDesign.Palette.secondaryAction, lineWidth: 2)
            }
        }
    }
}
