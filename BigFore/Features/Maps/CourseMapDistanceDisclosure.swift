import SwiftUI

struct CourseMapDistanceDisclosure: View {
    let viewModel: CourseMapViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                if let teeDistanceText = viewModel.teeToHolePinDistanceText {
                    CourseMapDistanceRow(title: "Tee to pin", value: teeDistanceText, isPrimary: true)
                }
                if let shotToPinText = viewModel.shotLocationToHolePinDistanceText,
                   viewModel.shotLocationToHolePinLabel != "Tee to pin" {
                    CourseMapDistanceRow(title: viewModel.shotLocationToHolePinLabel, value: shotToPinText)
                }
                if let courseMeasurementText = viewModel.measuredPointDistanceFromCourseText {
                    CourseMapDistanceRow(title: "Course to map pin", value: courseMeasurementText)
                }
                if let userMeasurementText = viewModel.measuredPointDistanceFromUserText {
                    CourseMapDistanceRow(title: "Me to map pin", value: userMeasurementText)
                }
                if viewModel.teeToHolePinDistanceText == nil,
                   viewModel.shotLocationToHolePinDistanceText == nil,
                   viewModel.measuredPointDistanceFromCourseText == nil,
                   viewModel.measuredPointDistanceFromUserText == nil {
                    Text("Set a tee, pin, or map pin to show distances.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, BigForeDesign.Spacing.small)
        } label: {
            Text("Distances")
                .font(.headline)
        }
    }
}
