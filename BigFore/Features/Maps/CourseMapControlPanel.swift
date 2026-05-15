import SwiftData
import SwiftUI

struct CourseMapControlPanel: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext
    let courseGeometries: [CourseGeometry]
    let activeGeometry: CourseGeometry?
    let geometrySummaryText: String?
    let activeGolfClubs: [GolfClub]
    let hasUserMappedTee: Bool
    let hasUserMappedPin: Bool
    @Binding var isDistancesExpanded: Bool
    let onCollapse: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                    header
                    geometryImportControls
                    holeNavigationControls
                    tapModeControls
                    CourseMapDistanceDisclosure(viewModel: viewModel, isExpanded: $isDistancesExpanded)

                    Divider()

                    manualShotControls

                    Divider()
                    statusMessages
                    cameraControls
                }
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 460)
            .padding(BigForeDesign.Spacing.large)

            Button("Collapse map controls", systemImage: "chevron.down", action: onCollapse)
                .labelStyle(.iconOnly)
                .font(.headline.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .buttonStyle(.plain)
                .accessibilityHint("Minimizes the control panel to the plus button.")
                .padding(BigForeDesign.Spacing.small)
        }
        .bigForePanelBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
            Text("Hole \(viewModel.targetHoleNumber)")
                .font(.title2.weight(.black))
                .monospacedDigit()
            Text(viewModel.course.courseName)
                .font(.headline)
                .lineLimit(1)
            Text(viewModel.mapSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(viewModel.locationService.locationStatusText)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.trailing, 44)
    }

    private var geometryImportControls: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
            Button {
                Task {
                    await viewModel.refreshOpenStreetMapGeometry(modelContext: modelContext)
                }
            } label: {
                if viewModel.isRefreshingGeometry {
                    Label("Finding OSM Geometry", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Label(activeGeometry == nil ? "Find OSM Geometry" : "Refresh OSM Geometry", systemImage: "map")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isRefreshingGeometry)

            if let geometrySummaryText {
                Text(geometrySummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let attribution = activeGeometry?.attribution {
                Text(attribution)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    @ViewBuilder
    private var holeNavigationControls: some View {
        if viewModel.availableHoles.count > 1 {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                HStack(spacing: BigForeDesign.Spacing.small) {
                    Button("Previous hole", systemImage: "chevron.left") {
                        viewModel.selectPreviousHole(geometries: courseGeometries, modelContext: modelContext)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!viewModel.canMoveToPreviousHole)
                    .accessibilityHint("Moves the map and score target to the previous hole.")

                    Picker("Hole", selection: Binding(
                        get: { viewModel.targetHoleNumber },
                        set: { viewModel.selectHole($0, geometries: courseGeometries, modelContext: modelContext) }
                    )) {
                        ForEach(viewModel.availableHoles, id: \.self) { holeNumber in
                            Text("Hole \(holeNumber)").tag(holeNumber)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityLabel("Current hole")

                    Button("Next hole", systemImage: "chevron.right") {
                        viewModel.selectNextHole(geometries: courseGeometries, modelContext: modelContext)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!viewModel.canMoveToNextHole)
                    .accessibilityHint("Moves the map and score target to the next hole.")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("Shots and scores target Hole \(viewModel.targetHoleNumber).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tapModeControls: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Text("Tap Sets")
                .font(.headline)
            selectionModeButtons
            Text(viewModel.selectionMode.tapInstruction)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(viewModel.manualShotHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if viewModel.teeBoxCoordinate != nil || viewModel.holePinCoordinate != nil {
                Button("Clear Setup") {
                    viewModel.clearHoleSetup(modelContext: modelContext)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            deleteStickyAnchorButtons
        }
    }

    private var selectionModeButtons: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BigForeDesign.Spacing.small) {
                ForEach(CourseMapSelectionMode.allCases) { mode in
                    if viewModel.selectionMode == mode {
                        Button(mode.title) {
                            viewModel.selectTapMode(mode, geometries: courseGeometries)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    } else {
                        Button(mode.title) {
                            viewModel.selectTapMode(mode, geometries: courseGeometries)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var deleteStickyAnchorButtons: some View {
        if hasUserMappedTee || hasUserMappedPin {
            HStack(spacing: BigForeDesign.Spacing.small) {
                if hasUserMappedTee {
                    Button("Delete Tee", role: .destructive) {
                        viewModel.deleteStickyHoleAnchor(kind: .teeBox, modelContext: modelContext, geometries: courseGeometries)
                    }
                }

                if hasUserMappedPin {
                    Button("Delete Pin", role: .destructive) {
                        viewModel.deleteStickyHoleAnchor(kind: .greenPin, modelContext: modelContext, geometries: courseGeometries)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
        }
    }

    private var manualShotControls: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Text("Manual Shots")
                .font(.headline)
            if let shotDistanceText = viewModel.shotDistanceText {
                LabeledContent(viewModel.isTrackingShot ? "Live distance" : "Shot distance", value: shotDistanceText)
                    .font(.headline)
                    .monospacedDigit()
            } else {
                Text("Start a shot, then mark the ball when you arrive.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            CourseMapShotSummaryList(viewModel: viewModel)
            clubSelectionControls
            woodyRecommendationCard
            CourseMapScoringControls(viewModel: viewModel, modelContext: modelContext)
            ViewThatFits(in: .horizontal) {
                CourseMapShotActionButtons(viewModel: viewModel, modelContext: modelContext)
                VStack(alignment: .leading) {
                    CourseMapShotActionButtons(viewModel: viewModel, modelContext: modelContext)
                }
            }
        }
    }

    @ViewBuilder
    private var clubSelectionControls: some View {
        if activeGolfClubs.isEmpty {
            Text("Add clubs in Bag so Woody can track distances.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
                Picker("Club", selection: Binding(
                    get: { viewModel.selectedClubID },
                    set: { newValue in
                        viewModel.selectedClubID = newValue
                        viewModel.applySelectedClubToCurrentShot(from: activeGolfClubs, modelContext: modelContext)
                    }
                )) {
                    ForEach(activeGolfClubs) { club in
                        Text(club.name).tag(Optional(club.id))
                    }
                }
                .pickerStyle(.menu)

                Text(viewModel.selectedClubAverageText(from: activeGolfClubs) ?? viewModel.selectedClubName(from: activeGolfClubs))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var woodyRecommendationCard: some View {
        if let recommendation = viewModel.clubRecommendation(from: activeGolfClubs) {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
                Label(recommendation.title, systemImage: "figure.golf")
                    .font(.callout.weight(.bold))

                Text(recommendation.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: BigForeDesign.Spacing.small) {
                    Text(recommendation.distanceText)
                    Text(recommendation.confidenceText)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

                if let weatherText = recommendation.weatherText {
                    Label(weatherText, systemImage: "cloud.sun")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(BigForeDesign.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BigForeDesign.Gradients.softFill(for: BigForeDesign.Palette.primaryAction), in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        if let statusMessage = viewModel.statusMessage {
            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        if let errorMessage = viewModel.errorMessage ?? viewModel.locationService.errorMessage {
            Text(errorMessage)
                .font(.callout)
                .foregroundStyle(BigForeDesign.Palette.destructive)
        }
    }

    private var cameraControls: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            ViewThatFits(in: .horizontal) {
                mapCameraButtons
                VStack(alignment: .leading) {
                    mapCameraButtons
                }
            }
            ViewThatFits(in: .horizontal) {
                mapAdjustmentButtons
                VStack(alignment: .leading) {
                    mapAdjustmentButtons
                }
            }
        }
    }

    private var mapCameraButtons: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Button("Course Center") {
                viewModel.showCourse()
            }
            if viewModel.locationService.currentLocation != nil {
                Button("My GPS") {
                    viewModel.showUser()
                }
            }
            if viewModel.teeBoxCoordinate != nil {
                Button("Tee") {
                    viewModel.showTeeBox()
                }
            }
            if viewModel.holePinCoordinate != nil {
                Button("Hole Pin") {
                    viewModel.showHolePin()
                }
            }
            if viewModel.shotMeasurementCoordinates != nil {
                Button("Shot Line") {
                    viewModel.showShotMeasurement()
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var mapAdjustmentButtons: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Button("Rotate left", systemImage: "rotate.left") {
                viewModel.rotateLeft()
            }
            .labelStyle(.iconOnly)

            Button("Rotate right", systemImage: "rotate.right") {
                viewModel.rotateRight()
            }
            .labelStyle(.iconOnly)

            Button("N") {
                viewModel.resetNorth()
            }
            .accessibilityLabel("Reset north")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
