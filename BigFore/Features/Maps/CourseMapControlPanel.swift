import SwiftData
import SwiftUI

struct CourseMapControlPanel: View {
    let courseMapViewModel: CourseMapViewModel
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
                    CourseMapDistanceDisclosure(courseMapViewModel: courseMapViewModel, isExpanded: $isDistancesExpanded)

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
            Text("Hole \(courseMapViewModel.targetHoleNumber)")
                .font(.title2.weight(.black))
                .monospacedDigit()
            Text(courseMapViewModel.course.courseName)
                .font(.headline)
                .lineLimit(1)
            Text(courseMapViewModel.mapSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(courseMapViewModel.locationService.locationStatusText)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.trailing, 44)
    }

    private var geometryImportControls: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
            Button {
                Task {
                    await courseMapViewModel.refreshOpenStreetMapGeometry(modelContext: modelContext)
                }
            } label: {
                if courseMapViewModel.isRefreshingGeometry {
                    Label("Finding OSM Geometry", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Label(activeGeometry == nil ? "Find OSM Geometry" : "Refresh OSM Geometry", systemImage: "map")
                }
            }
            .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            .controlSize(.small)
            .disabled(courseMapViewModel.isRefreshingGeometry)

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
        if courseMapViewModel.availableHoles.count > 1 {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                HStack(spacing: BigForeDesign.Spacing.small) {
                    Button("Previous hole", systemImage: "chevron.left") {
                        courseMapViewModel.selectPreviousHole(geometries: courseGeometries, modelContext: modelContext)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!courseMapViewModel.canMoveToPreviousHole)
                    .accessibilityHint("Moves the map and score target to the previous hole.")

                    Picker("Hole", selection: Binding(
                        get: { courseMapViewModel.targetHoleNumber },
                        set: { courseMapViewModel.selectHole($0, geometries: courseGeometries, modelContext: modelContext) }
                    )) {
                        ForEach(courseMapViewModel.availableHoles, id: \.self) { holeNumber in
                            Text("Hole \(holeNumber)").tag(holeNumber)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityLabel("Current hole")

                    Button("Next hole", systemImage: "chevron.right") {
                        courseMapViewModel.selectNextHole(geometries: courseGeometries, modelContext: modelContext)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!courseMapViewModel.canMoveToNextHole)
                    .accessibilityHint("Moves the map and score target to the next hole.")
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                .controlSize(.small)

                Text("Shots and scores target Hole \(courseMapViewModel.targetHoleNumber).")
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
            Text(courseMapViewModel.selectionMode.tapInstruction)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(courseMapViewModel.manualShotHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if courseMapViewModel.teeBoxCoordinate != nil || courseMapViewModel.holePinCoordinate != nil {
                Button("Clear Setup") {
                    courseMapViewModel.clearHoleSetup(modelContext: modelContext)
                }
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                .controlSize(.small)
            }
            deleteStickyAnchorButtons
        }
    }

    private var selectionModeButtons: some View {
        ScrollView(.horizontal) {
            HStack(spacing: BigForeDesign.Spacing.small) {
                ForEach(CourseMapSelectionMode.allCases) { mode in
                    if courseMapViewModel.selectionMode == mode {
                        Button(mode.title) {
                            courseMapViewModel.selectTapMode(mode, geometries: courseGeometries)
                        }
                        .buttonStyle(BigForePillButtonStyle.bigForePrimary)
                        .controlSize(.small)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    } else {
                        Button(mode.title) {
                            courseMapViewModel.selectTapMode(mode, geometries: courseGeometries)
                        }
                        .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
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
                        courseMapViewModel.deleteStickyHoleAnchor(kind: .teeBox, modelContext: modelContext, geometries: courseGeometries)
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForeDestructive)
                }

                if hasUserMappedPin {
                    Button("Delete Pin", role: .destructive) {
                        courseMapViewModel.deleteStickyHoleAnchor(kind: .greenPin, modelContext: modelContext, geometries: courseGeometries)
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForeDestructive)
                }
            }
            .controlSize(.small)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
        }
    }

    private var manualShotControls: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Text("Manual Shots")
                .font(.headline)
            if let shotDistanceText = courseMapViewModel.shotDistanceText {
                LabeledContent(courseMapViewModel.isTrackingShot ? "Live distance" : "Shot distance", value: shotDistanceText)
                    .font(.headline)
                    .monospacedDigit()
            } else {
                Text("Start a shot, then mark the ball when you arrive.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            CourseMapShotSummaryList(courseMapViewModel: courseMapViewModel)
            clubSelectionControls
            woodyRecommendationCard
            CourseMapScoringControls(courseMapViewModel: courseMapViewModel, modelContext: modelContext)
            ViewThatFits(in: .horizontal) {
                CourseMapShotActionButtons(courseMapViewModel: courseMapViewModel, modelContext: modelContext)
                VStack(alignment: .leading) {
                    CourseMapShotActionButtons(courseMapViewModel: courseMapViewModel, modelContext: modelContext)
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
                    get: { courseMapViewModel.selectedClubID },
                    set: { newValue in
                        courseMapViewModel.selectedClubID = newValue
                        courseMapViewModel.applySelectedClubToCurrentShot(from: activeGolfClubs, modelContext: modelContext)
                    }
                )) {
                    ForEach(activeGolfClubs) { club in
                        Text(club.name).tag(Optional(club.id))
                    }
                }
                .pickerStyle(.menu)

                Text(courseMapViewModel.selectedClubAverageText(from: activeGolfClubs) ?? courseMapViewModel.selectedClubName(from: activeGolfClubs))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var woodyRecommendationCard: some View {
        if let recommendation = courseMapViewModel.clubRecommendation(from: activeGolfClubs, geometries: courseGeometries) {
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
        if let statusMessage = courseMapViewModel.statusMessage {
            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        if let errorMessage = courseMapViewModel.errorMessage ?? courseMapViewModel.locationService.errorMessage {
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
                courseMapViewModel.showCourse()
            }
            if courseMapViewModel.locationService.currentLocation != nil {
                Button("My GPS") {
                    courseMapViewModel.showUser()
                }
            }
            if courseMapViewModel.teeBoxCoordinate != nil {
                Button("Tee") {
                    courseMapViewModel.showTeeBox()
                }
            }
            if courseMapViewModel.holePinCoordinate != nil {
                Button("Hole Pin") {
                    courseMapViewModel.showHolePin()
                }
            }
            if courseMapViewModel.shotMeasurementCoordinates != nil {
                Button("Shot Line") {
                    courseMapViewModel.showShotMeasurement()
                }
            }
        }
        .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var mapAdjustmentButtons: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Button("Zoom in", systemImage: "plus.magnifyingglass") {
                courseMapViewModel.zoomIn()
            }
            .labelStyle(.iconOnly)

            Button("Zoom out", systemImage: "minus.magnifyingglass") {
                courseMapViewModel.zoomOut()
            }
            .labelStyle(.iconOnly)

            Button("Rotate left", systemImage: "rotate.left") {
                courseMapViewModel.rotateLeft()
            }
            .labelStyle(.iconOnly)

            Button("Rotate right", systemImage: "rotate.right") {
                courseMapViewModel.rotateRight()
            }
            .labelStyle(.iconOnly)

            Button("N") {
                courseMapViewModel.resetNorth()
            }
            .accessibilityLabel("Reset north")
        }
        .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
        .controlSize(.small)
        .font(.callout.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
