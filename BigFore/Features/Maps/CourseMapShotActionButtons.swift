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
                if viewModel.shotStartCoordinate != nil {
                    Button("GPS Ball") {
                        viewModel.markShotEndAtCurrentLocation(modelContext: modelContext)
                    }
                }
            }
            if viewModel.measuredCoordinate != nil {
                Button("Pin Start") {
                    viewModel.startShotFromMeasuredPoint()
                }
                if viewModel.shotStartCoordinate != nil {
                    Button("Pin Ball") {
                        viewModel.markShotEndAtMeasuredPoint(modelContext: modelContext)
                    }
                }
            }
            if viewModel.canStartNextShotFromBall {
                Button("Next") {
                    viewModel.startNextShotFromBall()
                }
            }
            if viewModel.selectedShotMarker != nil {
                Button("Move") {
                    viewModel.selectionMode = .moveShotBall
                }
                Button("Delete", role: .destructive) {
                    viewModel.deleteSelectedShotMarker(modelContext: modelContext)
                }
            }
            if viewModel.shotStartCoordinate != nil {
                Button("Clear") {
                    viewModel.clearShotMeasurement()
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
