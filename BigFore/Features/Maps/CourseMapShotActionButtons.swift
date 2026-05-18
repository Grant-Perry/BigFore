import SwiftData
import SwiftUI

struct CourseMapShotActionButtons: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            if viewModel.locationService.currentLocation != nil {
                Button(viewModel.isTrackingShot ? "GPS" : "GPS Start") {
                    viewModel.startShotFromCurrentLocation()
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                if viewModel.shotStartCoordinate != nil {
                    Button("GPS Ball") {
                        viewModel.markShotEndAtCurrentLocation(modelContext: modelContext)
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                }
            }
            if viewModel.measuredCoordinate != nil {
                Button("Pin Start") {
                    viewModel.startShotFromMeasuredPoint()
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                if viewModel.shotStartCoordinate != nil {
                    Button("Pin Ball") {
                        viewModel.markShotEndAtMeasuredPoint(modelContext: modelContext)
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                }
            }
            if viewModel.canStartNextShotFromBall {
                Button("Next") {
                    viewModel.startNextShotFromBall()
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            }
            if viewModel.selectedShotMarker != nil {
                Button("Move") {
                    viewModel.selectionMode = .moveShotBall
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                Button("Delete", role: .destructive) {
                    viewModel.deleteSelectedShotMarker(modelContext: modelContext)
                }
                .buttonStyle(BigForePillButtonStyle.bigForeDestructive)
            }
            if viewModel.shotStartCoordinate != nil {
                Button("Clear") {
                    viewModel.clearShotMeasurement()
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
