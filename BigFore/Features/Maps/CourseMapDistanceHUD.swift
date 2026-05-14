import SwiftUI

struct CourseMapDistanceHUD: View {
    let viewModel: CourseMapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: BigForeDesign.Spacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hole \(viewModel.targetHoleNumber)")
                        .font(.headline.weight(.bold))
                    Text(viewModel.holeParText(for: viewModel.targetHoleNumber) ?? viewModel.course.clubName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: BigForeDesign.Spacing.large)

                if let teeDistanceText = viewModel.teeToHolePinDistanceText {
                    yardageBlock(title: "Tee to pin", value: teeDistanceText)
                } else {
                    yardageBlock(title: "Setup", value: "Set tee + pin")
                }
            }

            if let shotToPinText = viewModel.shotLocationToHolePinDistanceText,
               viewModel.shotLocationToHolePinLabel != "Tee to pin" {
                secondaryDistanceRow(title: viewModel.shotLocationToHolePinLabel, value: shotToPinText)
            }

            if let shotDistanceText = viewModel.shotDistanceText {
                secondaryDistanceRow(
                    title: viewModel.isTrackingShot ? "Live shot" : "Shot distance",
                    value: shotDistanceText
                )
            }
        }
        .padding(.horizontal, BigForeDesign.Spacing.large)
        .padding(.vertical, BigForeDesign.Spacing.medium)
        .frame(maxWidth: 360, alignment: .leading)
        .bigForePanelBackground()
        .accessibilityElement(children: .combine)
    }

    private func yardageBlock(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value)
                .font(.title2.weight(.black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func secondaryDistanceRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: BigForeDesign.Spacing.large)
            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
