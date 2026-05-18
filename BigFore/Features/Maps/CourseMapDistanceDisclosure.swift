import SwiftUI

struct CourseMapDistanceDisclosure: View {
    let courseMapViewModel: CourseMapViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                if let teeDistanceText = courseMapViewModel.teeToHolePinDistanceText {
                    CourseMapDistanceRow(title: "Tee to pin", value: teeDistanceText, isPrimary: true)
                }
                if let shotToPinText = courseMapViewModel.shotLocationToHolePinDistanceText,
                   courseMapViewModel.shotLocationToHolePinLabel != "Tee to pin" {
                    CourseMapDistanceRow(title: courseMapViewModel.shotLocationToHolePinLabel, value: shotToPinText)
                }
                if let courseMeasurementText = courseMapViewModel.measuredPointDistanceFromCourseText {
                    CourseMapDistanceRow(title: "Course to map pin", value: courseMeasurementText)
                }
                if let userMeasurementText = courseMapViewModel.measuredPointDistanceFromUserText {
                    CourseMapDistanceRow(title: "Me to map pin", value: userMeasurementText)
                }
                if courseMapViewModel.teeToHolePinDistanceText == nil,
                   courseMapViewModel.shotLocationToHolePinDistanceText == nil,
                   courseMapViewModel.measuredPointDistanceFromCourseText == nil,
                   courseMapViewModel.measuredPointDistanceFromUserText == nil {
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
