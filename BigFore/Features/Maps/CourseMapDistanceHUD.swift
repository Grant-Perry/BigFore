import Foundation
import SwiftUI

struct CourseMapVenueChip: View {
    let viewModel: CourseMapViewModel

    var body: some View {
        Text(viewModel.course.courseName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, BigForeDesign.Spacing.large)
            .padding(.vertical, BigForeDesign.Spacing.small)
            .frame(maxWidth: 280)
            .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.capsulePanel)
            .accessibilityLabel("Course")
            .accessibilityValue(viewModel.course.courseName)
    }
}

struct CourseMapDistanceMetricStack: View {
    let viewModel: CourseMapViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: BigForeDesign.Spacing.small) {
            metricCard(title: "Hole", value: "\(viewModel.targetHoleNumber)", detail: viewModel.holeParText(for: viewModel.targetHoleNumber))

            if let teeDistanceText = viewModel.teeToHolePinDistanceText {
                metricCard(title: "Tee to pin", value: displayDistance(teeDistanceText))
            } else {
                metricCard(title: "Setup", value: "Set", detail: "Tee + pin")
            }

            if let shotToPinText = viewModel.shotLocationToHolePinDistanceText,
               viewModel.shotLocationToHolePinLabel != "Tee to pin" {
                metricCard(title: viewModel.shotLocationToHolePinLabel, value: displayDistance(shotToPinText))
            }

            if let shotDistanceText = viewModel.shotDistanceText {
                metricCard(
                    title: viewModel.isTrackingShot ? "Live shot" : "Shot distance",
                    value: displayDistance(shotDistanceText)
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metricCard(title: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.headline.weight(.black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.small)
        .frame(width: 112, alignment: .trailing)
        .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.card, materialOpacity: 0.58)
    }

    private func displayDistance(_ distanceText: String) -> String {
        let components = distanceText.split(separator: " ")
        guard components.count == 2,
              components[1] == "yds",
              let yards = Int(components[0]),
              yards >= 1_760 else {
            return distanceText
        }

        let miles = Double(yards) / 1_760
        return "\(miles.formatted(.number.grouping(.never).precision(.fractionLength(1)))) miles"
    }
}
