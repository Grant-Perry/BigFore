import SwiftData
import SwiftUI

struct CourseMapShotActionButtons: View {
    let courseMapViewModel: CourseMapViewModel
    let modelContext: ModelContext

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            if courseMapViewModel.locationService.currentLocation != nil {
                Button(courseMapViewModel.isTrackingShot ? "GPS" : "GPS Start") {
                    courseMapViewModel.startShotFromCurrentLocation()
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                if courseMapViewModel.shotStartCoordinate != nil {
                    Button("GPS Ball") {
                        courseMapViewModel.markShotEndAtCurrentLocation(modelContext: modelContext)
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                }
            }
            if courseMapViewModel.measuredCoordinate != nil {
                Button("Pin Start") {
                    courseMapViewModel.startShotFromMeasuredPoint()
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                if courseMapViewModel.shotStartCoordinate != nil {
                    Button("Pin Ball") {
                        courseMapViewModel.markShotEndAtMeasuredPoint(modelContext: modelContext)
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                }
            }
            if courseMapViewModel.canStartNextShotFromBall {
                Button("Next") {
                    courseMapViewModel.startNextShotFromBall()
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            }
            if courseMapViewModel.selectedShotMarker != nil {
                Button("Move") {
                    courseMapViewModel.selectionMode = .moveShotBall
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                Button("Delete", role: .destructive) {
                    courseMapViewModel.deleteSelectedShotMarker(modelContext: modelContext)
                }
                .buttonStyle(BigForePillButtonStyle.bigForeDestructive)
            }
            if courseMapViewModel.shotStartCoordinate != nil {
                Button("Clear") {
                    courseMapViewModel.clearShotMeasurement()
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            }
        }
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
