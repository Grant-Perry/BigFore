import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct CourseMapPoint: Identifiable, Hashable {
    let id: Int
    let courseName: String
    let clubName: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct CourseMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var courseGeometries: [CourseGeometry]
    @State private var viewModel: CourseMapViewModel
    @AppStorage("courseMap.isControlPanelExpanded") private var isControlPanelExpanded = true
    @AppStorage("courseMap.isDistancesExpanded") private var isDistancesExpanded = true
    @AppStorage("courseMap.isSaveTargetExpanded") private var isSaveTargetExpanded = false

    init(course: CourseMapPoint, currentHoleNumber: Int? = nil, round: GolfRound? = nil) {
        _viewModel = State(initialValue: CourseMapViewModel(course: course, currentHoleNumber: currentHoleNumber, round: round))
        let courseExternalID = course.id
        _courseGeometries = Query(
            filter: #Predicate<CourseGeometry> { geometry in
                geometry.courseExternalID == courseExternalID
            },
            sort: \.updatedAt,
            order: .reverse
        )
    }

    private var mappedFeaturePoints: [CourseMapFeaturePoint] {
        courseGeometries
            .flatMap(\.holes)
            .flatMap(\.featurePoints)
            .filter { !$0.kind.isStickyHoleAnchor }
            .sorted {
                let lhsHole = $0.holeGeometry?.number ?? 0
                let rhsHole = $1.holeGeometry?.number ?? 0
                if lhsHole == rhsHole {
                    return $0.sortOrder < $1.sortOrder
                }

                return lhsHole < rhsHole
            }
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack(alignment: .bottomTrailing) {
            MapReader { proxy in
                Map(position: $viewModel.position, interactionModes: .all) {
                    Marker(viewModel.course.courseName, coordinate: viewModel.course.coordinate)
                    UserAnnotation()

                    if let measuredCoordinate = viewModel.measuredCoordinate {
                        Marker("Measured Point", systemImage: "mappin.and.ellipse", coordinate: measuredCoordinate)
                            .tint(.orange)
                    }

                    if let teeBoxCoordinate = viewModel.teeBoxCoordinate {
                        Marker("Tee Box", systemImage: "figure.golf", coordinate: teeBoxCoordinate)
                            .tint(.blue)
                    }

                    if let holePinCoordinate = viewModel.holePinCoordinate {
                        Marker("Hole Pin", systemImage: "flag.fill", coordinate: holePinCoordinate)
                            .tint(.red)
                    }

                    ForEach(mappedFeaturePoints) { featurePoint in
                        Marker(featurePoint.markerTitle, systemImage: featurePoint.kind.mapSystemImage, coordinate: featurePoint.coordinate)
                            .tint(featurePoint.kind.mapTint)
                    }

                    if let courseToMeasuredCoordinates = viewModel.courseToMeasuredCoordinates {
                        MapPolyline(coordinates: courseToMeasuredCoordinates)
                            .stroke(.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }

                    if let userToMeasuredCoordinates = viewModel.userToMeasuredCoordinates {
                        MapPolyline(coordinates: userToMeasuredCoordinates)
                            .stroke(.green, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }

                    if let teeToHolePinCoordinates = viewModel.teeToHolePinCoordinates {
                        MapPolyline(coordinates: teeToHolePinCoordinates)
                            .stroke(.red, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                    }

                    if let shotLocationToHolePinCoordinates = viewModel.shotLocationToHolePinCoordinates {
                        MapPolyline(coordinates: shotLocationToHolePinCoordinates)
                            .stroke(.mint, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }

                    if let shotStartCoordinate = viewModel.shotStartCoordinate {
                        Marker("Shot Start", systemImage: "figure.golf", coordinate: shotStartCoordinate)
                            .tint(.blue)
                    }

                    if let shotEndCoordinate = viewModel.shotEndCoordinate {
                        Marker("Ball", systemImage: "smallcircle.filled.circle", coordinate: shotEndCoordinate)
                            .tint(.green)
                    }

                    ForEach(viewModel.shotMarkers) { shotMarker in
                        Annotation("Shot \(shotMarker.shotNumber)", coordinate: shotMarker.ballCoordinate, anchor: .center) {
                            Button {
                                viewModel.selectShotMarker(id: shotMarker.id)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 28, height: 28)
                                    Text("\(shotMarker.shotNumber)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Shot \(shotMarker.shotNumber) ball marker")
                        }
                    }

                    if let shotMeasurementCoordinates = viewModel.shotMeasurementCoordinates {
                        MapPolyline(coordinates: shotMeasurementCoordinates)
                            .stroke(.blue, lineWidth: 3)
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapPitchToggle()
                    MapUserLocationButton()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    viewModel.updateCameraState(context.camera)
                }
                .onTapGesture(coordinateSpace: .local) { point in
                    if let coordinate = proxy.convert(point, from: .local) {
                        collapseControlPanel()
                        viewModel.handleMapTap(at: coordinate, modelContext: modelContext)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            if isControlPanelExpanded {
                ZStack(alignment: .topTrailing) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.course.courseName)
                                    .font(.headline)
                                Text(viewModel.mapSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.trailing, 36)

                            Text(viewModel.locationService.locationStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            holeNavigationControls(viewModel: viewModel, modelContext: modelContext)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Tap Sets")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                selectionModeButtons(viewModel: viewModel)
                                Text(viewModel.selectionMode.tapInstruction)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(viewModel.manualShotHelpText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                if viewModel.teeBoxCoordinate != nil || viewModel.holePinCoordinate != nil {
                                    Button("Clear Setup") {
                                        viewModel.clearHoleSetup(modelContext: modelContext)
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption2)
                                    .lineLimit(1)
                                }
                            }

                            distanceDisclosure(viewModel: viewModel, isExpanded: $isDistancesExpanded)

                            Divider()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Manual Shots")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                if let shotDistanceText = viewModel.shotDistanceText {
                                    LabeledContent(viewModel.isTrackingShot ? "Live distance" : "Shot distance", value: shotDistanceText)
                                } else {
                                    Text("Start a shot, then mark the ball when you arrive.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                shotSummaryList(viewModel: viewModel)
                                scoringControls(viewModel: viewModel)
                                ViewThatFits(in: .horizontal) {
                                    shotDistanceButtons(viewModel: viewModel, modelContext: modelContext)
                                    VStack(alignment: .leading) {
                                        shotDistanceButtons(viewModel: viewModel, modelContext: modelContext)
                                    }
                                }
                            }

                            Divider()

                            saveTargetDisclosure(viewModel: viewModel, isExpanded: $isSaveTargetExpanded)

                            if let statusMessage = viewModel.statusMessage {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let errorMessage = viewModel.errorMessage ?? viewModel.locationService.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            ViewThatFits(in: .horizontal) {
                                mapCameraButtons(viewModel: viewModel)
                                VStack(alignment: .leading) {
                                    mapCameraButtons(viewModel: viewModel)
                                }
                            }
                            ViewThatFits(in: .horizontal) {
                                mapAdjustmentButtons(viewModel: viewModel)
                                VStack(alignment: .leading) {
                                    mapAdjustmentButtons(viewModel: viewModel)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: 420)
                    .padding()

                    Button(action: collapseControlPanel) {
                        Label("Collapse map controls", systemImage: "chevron.down")
                            .labelStyle(.iconOnly)
                            .font(.caption.weight(.semibold))
                            .frame(width: 30, height: 30)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Minimizes the control panel to the plus button.")
                    .padding(10)
                }
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.regularMaterial.opacity(0.7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.background.opacity(0.32))
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded(handleControlPanelDrag)
                )
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                collapsedActionButtons(viewModel: viewModel, modelContext: modelContext)
                .padding(.trailing, 16)
                .padding(.bottom, 82)
                .transition(.scale.combined(with: .opacity))
            }

            bottomLeadingMapControls(viewModel: viewModel, modelContext: modelContext)
                .padding(.leading)
                .padding(.bottom, isControlPanelExpanded ? 456 : 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .animation(.snappy, value: isControlPanelExpanded)
        .animation(.snappy, value: isDistancesExpanded)
        .animation(.snappy, value: isSaveTargetExpanded)
        .navigationTitle("Course Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.applyStoredHoleSetup(from: courseGeometries)
            viewModel.requestLocationAccess()
        }
        .onChange(of: courseGeometries.map(\.updatedAt)) {
            viewModel.applyStoredHoleSetup(from: courseGeometries)
        }
        .onChange(of: viewModel.targetHoleNumber) {
            viewModel.applyStoredHoleSetup(from: courseGeometries)
        }
    }

    private func expandControlPanel() {
        withAnimation(.snappy) {
            isControlPanelExpanded = true
        }
    }

    private func collapseControlPanel() {
        withAnimation(.snappy) {
            isControlPanelExpanded = false
        }
    }

    private func handleControlPanelDrag(_ value: DragGesture.Value) {
        let verticalMovement = value.translation.height
        let horizontalMovement = abs(value.translation.width)
        guard verticalMovement > 50, verticalMovement > horizontalMovement else {
            return
        }

        collapseControlPanel()
    }

    @ViewBuilder
    private func holeNavigationControls(viewModel: CourseMapViewModel, modelContext: ModelContext) -> some View {
        if viewModel.availableHoles.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Button {
                        viewModel.selectPreviousHole(geometries: courseGeometries, modelContext: modelContext)
                    } label: {
                        Label("Previous hole", systemImage: "chevron.left")
                            .labelStyle(.iconOnly)
                    }
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

                    Button {
                        viewModel.selectNextHole(geometries: courseGeometries, modelContext: modelContext)
                    } label: {
                        Label("Next hole", systemImage: "chevron.right")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!viewModel.canMoveToNextHole)
                    .accessibilityHint("Moves the map and score target to the next hole.")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Text("Shots and scores target Hole \(viewModel.targetHoleNumber).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func selectionModeButtons(viewModel: CourseMapViewModel) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(CourseMapSelectionMode.allCases) { mode in
                    if viewModel.selectionMode == mode {
                        Button(mode.title) {
                            viewModel.selectionMode = mode
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    } else {
                        Button(mode.title) {
                            viewModel.selectionMode = mode
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func distanceDisclosure(viewModel: CourseMapViewModel, isExpanded: Binding<Bool>) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                if let teeDistanceText = viewModel.teeToHolePinDistanceText {
                    compactDistanceRow("Tee to pin", value: teeDistanceText)
                }
                if let shotToPinText = viewModel.shotLocationToHolePinDistanceText,
                   viewModel.shotLocationToHolePinLabel != "Tee to pin" {
                    compactDistanceRow(viewModel.shotLocationToHolePinLabel, value: shotToPinText)
                }
                if let courseMeasurementText = viewModel.measuredPointDistanceFromCourseText {
                    compactDistanceRow("Course to map pin", value: courseMeasurementText)
                }
                if let userMeasurementText = viewModel.measuredPointDistanceFromUserText {
                    compactDistanceRow("Me to map pin", value: userMeasurementText)
                }
                if viewModel.teeToHolePinDistanceText == nil,
                   viewModel.shotLocationToHolePinDistanceText == nil,
                   viewModel.measuredPointDistanceFromCourseText == nil,
                   viewModel.measuredPointDistanceFromUserText == nil {
                    Text("Set a tee, pin, or map pin to show distances.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        } label: {
            Text("Distances")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func compactDistanceRow(_ title: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } label: {
            Text(title)
                .font(.callout)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private func shotSummaryList(viewModel: CourseMapViewModel) -> some View {
        if viewModel.shotSummaries.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 6) {
                ForEach(viewModel.shotSummaries) { summary in
                    Button {
                        viewModel.selectShotMarker(id: summary.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Shot \(summary.shotNumber)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(summary.distanceFromPreviousText)
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            Text(summary.shotNumber == 1 ? "From tee/SOT" : "From previous ball")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let distanceToPinText = summary.distanceToPinText {
                                Text("To pin: \(distanceToPinText)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Set the pin to show distance to hole.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            if summary.isSelected {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.blue, lineWidth: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select shot \(summary.shotNumber)")
                }
            }
        }
    }

    @ViewBuilder
    private func scoringControls(viewModel: CourseMapViewModel) -> some View {
        @Bindable var viewModel = viewModel

        if viewModel.scoringPlayers.isEmpty == false {
            if viewModel.scoringPlayers.count > 1 {
                Picker("Scoring player", selection: $viewModel.selectedScoringPlayerID) {
                    ForEach(viewModel.scoringPlayers) { player in
                        Text(player.name).tag(Optional(player.id))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedScoringPlayerID) {
                    viewModel.syncManualShotCountToScore(modelContext: modelContext)
                }
            }

            if let manualShotScoreText = viewModel.manualShotScoreText {
                Text(manualShotScoreText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                viewModel.saveCurrentHole(modelContext: modelContext)
            } label: {
                Label(viewModel.saveHoleButtonTitle, systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.mini)
            .disabled(!viewModel.canSaveHole)
            .accessibilityLabel(Text(viewModel.saveHoleActionAccessibilityLabel))

            if let saveHoleHelpText = viewModel.saveHoleHelpText {
                Text(saveHoleHelpText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func saveTargetDisclosure(viewModel: CourseMapViewModel, isExpanded: Binding<Bool>) -> some View {
        @Bindable var viewModel = viewModel

        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hazard, layup, dogleg, and target stay saved for Hole \(viewModel.targetHoleNumber).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Target type", selection: $viewModel.selectedFeatureKind) {
                    ForEach(CourseMapFeatureKind.saveableTargetKinds) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                TextField(viewModel.defaultFeatureLabel, text: $viewModel.featureLabel)
                    .textInputAutocapitalization(.words)
                Button("Save Target") {
                    viewModel.saveMeasuredPointAsFeature(modelContext: modelContext)
                }
                .buttonStyle(.borderedProminent)
                .font(.caption2)
                .lineLimit(1)
                .disabled(viewModel.measuredCoordinate == nil)
            }
            .padding(.top, 6)
        } label: {
            Text("Save Target")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private func shotDistanceButtons(viewModel: CourseMapViewModel, modelContext: ModelContext) -> some View {
        HStack(spacing: 6) {
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
            }
            if viewModel.shotStartCoordinate != nil {
                Button("Clear") {
                    viewModel.clearShotMeasurement()
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    @ViewBuilder
    private func mapCameraButtons(viewModel: CourseMapViewModel) -> some View {
        HStack(spacing: 6) {
            Button("Course Center") {
                viewModel.showCourse()
            }
            if viewModel.locationService.currentLocation != nil {
                Button("My GPS") {
                    viewModel.showUser()
                }
            }
            if viewModel.measuredCoordinate != nil {
                Button("Map Pin") {
                    viewModel.showMeasuredPin()
                }
                Button("Clear Map Pin") {
                    viewModel.clearMeasuredPoint()
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
        .controlSize(.mini)
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    @ViewBuilder
    private func mapAdjustmentButtons(viewModel: CourseMapViewModel) -> some View {
        HStack(spacing: 6) {
            Button {
                viewModel.rotateLeft()
            } label: {
                Image(systemName: "rotate.left")
            }
            .accessibilityLabel("Rotate left")
            Button {
                viewModel.rotateRight()
            } label: {
                Image(systemName: "rotate.right")
            }
            .accessibilityLabel("Rotate right")
            Button("N") {
                viewModel.resetNorth()
            }
            .accessibilityLabel("Reset north")
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private func bottomLeadingMapControls(viewModel: CourseMapViewModel, modelContext: ModelContext) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                compactZoomControls(viewModel: viewModel)
                compactHoleActionControls(viewModel: viewModel, modelContext: modelContext)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing)
        }
        .scrollIndicators(.hidden)
    }

    private func collapsedActionButtons(viewModel: CourseMapViewModel, modelContext: ModelContext) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.saveCurrentHole(modelContext: modelContext)
            } label: {
                Label(viewModel.saveHoleButtonTitle, systemImage: "checkmark")
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.green.opacity(viewModel.canSaveHole ? 0.92 : 0.28), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSaveHole)
            .opacity(viewModel.canSaveHole ? 1 : 0.55)
            .accessibilityLabel(Text(viewModel.saveHoleActionAccessibilityLabel))
            .accessibilityHint("Syncs the current hole score before advancing.")

            Button(action: expandControlPanel) {
                Label("Show map controls", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func compactZoomControls(viewModel: CourseMapViewModel) -> some View {
        HStack(spacing: 8) {
            Button {
                viewModel.zoomIn()
            } label: {
                Label("Zoom in", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 34, height: 34)
            }

            Button {
                viewModel.zoomOut()
            } label: {
                Label("Zoom out", systemImage: "minus")
                    .labelStyle(.iconOnly)
                    .frame(width: 34, height: 34)
            }
        }
        .font(.callout.weight(.semibold))
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.regularMaterial.opacity(0.7))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(.background.opacity(0.32))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func compactHoleActionControls(viewModel: CourseMapViewModel, modelContext: ModelContext) -> some View {
        HStack(spacing: 6) {
            Menu {
                Picker("Hole", selection: Binding(
                    get: { viewModel.targetHoleNumber },
                    set: { viewModel.selectHole($0, geometries: courseGeometries, modelContext: modelContext) }
                )) {
                    ForEach(viewModel.availableHoles, id: \.self) { holeNumber in
                        Text("Hole \(holeNumber)").tag(holeNumber)
                    }
                }
            } label: {
                compactControlLabel("H\(viewModel.targetHoleNumber)", systemImage: "chevron.up.chevron.down")
            }
            .accessibilityLabel("Current hole")
            .accessibilityValue("Hole \(viewModel.targetHoleNumber)")
            .accessibilityHint("Focuses the selected hole on the map.")

            compactTapModeButton(
                "Start",
                systemImage: "flag.checkered",
                accessibilityLabel: "Set shot start",
                mode: .shotStart,
                viewModel: viewModel
            ) {
                viewModel.setShotStartTapMode()
            }

            compactTapModeButton(
                "Ball",
                systemImage: "smallcircle.filled.circle",
                accessibilityLabel: "Set ball location",
                mode: .shotBall,
                viewModel: viewModel
            ) {
                viewModel.setShotBallTapMode()
            }

            Button {
                viewModel.startNextShotFromBall()
            } label: {
                compactIconLabel("Start next shot", systemImage: "chevron.right")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canStartNextShotFromBall)
            .accessibilityHint("Starts the next shot from the last marked ball.")

            compactTapModeButton(
                "T\(viewModel.targetHoleNumber)",
                accessibilityLabel: "Set tee box for Hole \(viewModel.targetHoleNumber)",
                mode: .teeBox,
                viewModel: viewModel
            ) {
                viewModel.setTeeBoxTapMode()
            }

            compactTapModeButton(
                "P\(viewModel.targetHoleNumber)",
                accessibilityLabel: "Set hole pin for Hole \(viewModel.targetHoleNumber)",
                mode: .holePin,
                viewModel: viewModel
            ) {
                viewModel.setHolePinTapMode()
            }
        }
        .controlSize(.mini)
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.regularMaterial.opacity(0.7))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(.background.opacity(0.32))
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    @ViewBuilder
    private func compactTapModeButton(
        _ title: String,
        systemImage: String? = nil,
        accessibilityLabel: String? = nil,
        mode: CourseMapSelectionMode,
        viewModel: CourseMapViewModel,
        action: @escaping () -> Void
    ) -> some View {
        if viewModel.selectionMode == mode {
            Button(action: action) {
                compactTapModeLabel(title, systemImage: systemImage)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(Text(accessibilityLabel ?? title))
        } else {
            Button(action: action) {
                compactTapModeLabel(title, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(Text(accessibilityLabel ?? title))
        }
    }

    @ViewBuilder
    private func compactTapModeLabel(_ title: String, systemImage: String?) -> some View {
        if let systemImage {
            compactIconLabel(title, systemImage: systemImage)
        } else {
            compactControlLabel(title)
        }
    }

    private func compactControlLabel(_ title: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 3) {
            Text(title)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .imageScale(.small)
            }
        }
        .frame(minWidth: systemImage == nil ? 30 : 42, maxHeight: 22)
        .padding(.horizontal, 2)
    }

    private func compactIconLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .frame(width: 24, height: 22)
    }
}

extension CourseMapPoint {
    init?(apiCourse: GolfCourseAPICourse) {
        guard let latitude = apiCourse.location.latitude, let longitude = apiCourse.location.longitude else {
            return nil
        }
        self.init(id: apiCourse.id, courseName: apiCourse.courseName, clubName: apiCourse.clubName, latitude: latitude, longitude: longitude)
    }

    init?(savedCourse: GolfCourse) {
        guard let latitude = savedCourse.latitude, let longitude = savedCourse.longitude else {
            return nil
        }
        self.init(id: savedCourse.externalID, courseName: savedCourse.courseName, clubName: savedCourse.clubName, latitude: latitude, longitude: longitude)
    }

    init?(round: GolfRound) {
        guard let latitude = round.courseLatitude, let longitude = round.courseLongitude else {
            return nil
        }
        self.init(id: round.courseExternalID, courseName: round.courseName, clubName: round.clubName, latitude: latitude, longitude: longitude)
    }

    init?(roundSetupCourse: RoundSetupCourse) {
        guard let latitude = roundSetupCourse.latitude, let longitude = roundSetupCourse.longitude else {
            return nil
        }
        self.init(id: roundSetupCourse.externalID, courseName: roundSetupCourse.courseName, clubName: roundSetupCourse.clubName, latitude: latitude, longitude: longitude)
    }
}

private extension CourseMapFeaturePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var markerTitle: String {
        if let holeNumber = holeGeometry?.number {
            return "Hole \(holeNumber) \(label)"
        }

        return label
    }
}

private extension CourseMapFeatureKind {
    var mapSystemImage: String {
        switch self {
        case .teeBox:
            "figure.golf"
        case .greenPin:
            "flag.fill"
        case .dogleg:
            "arrow.turn.up.right"
        case .hazard:
            "exclamationmark.triangle.fill"
        case .layup:
            "flag.checkered"
        case .target:
            "scope"
        }
    }

    var mapTint: Color {
        switch self {
        case .teeBox:
            .blue
        case .greenPin:
            .red
        case .dogleg:
            .purple
        case .hazard:
            .red
        case .layup:
            .yellow
        case .target:
            .cyan
        }
    }
}
