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
    @State private var isMeasuredPointDeleteVisible = false
    @State private var hasFocusedInitialRoundHole = false
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
            .filter { $0.number == viewModel.targetHoleNumber }
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

    private var mappedTeeMarkers: [CourseMapHoleMarker] {
        courseGeometries
            .flatMap(\.holes)
            .filter { $0.number != viewModel.targetHoleNumber }
            .compactMap { hole in
                let teePoint = preferredFeaturePoint(kind: .teeBox, in: hole.featurePoints)
                guard let teePoint else {
                    return nil
                }

                return CourseMapHoleMarker(
                    id: "tee-\(hole.number)",
                    holeNumber: hole.number,
                    coordinate: teePoint.coordinate,
                    kind: .tee
                )
            }
            .sorted { $0.holeNumber < $1.holeNumber }
    }

    private var mappedPinMarkers: [CourseMapHoleMarker] {
        courseGeometries
            .flatMap(\.holes)
            .filter { $0.number != viewModel.targetHoleNumber }
            .compactMap { hole in
                let userPin = preferredFeaturePoint(kind: .greenPin, in: hole.featurePoints)
                let coordinate = userPin?.coordinate ?? hole.greenCenterCoordinate
                guard let coordinate else {
                    return nil
                }

                return CourseMapHoleMarker(
                    id: "pin-\(hole.number)",
                    holeNumber: hole.number,
                    coordinate: coordinate,
                    kind: .pin
                )
            }
            .sorted { $0.holeNumber < $1.holeNumber }
    }

    private var activeGeometry: CourseGeometry? {
        courseGeometries.first
    }

    private var geometrySummaryText: String? {
        guard let activeGeometry else {
            return nil
        }

        let mappedHoleCount = mappedHoleCount(for: activeGeometry)
        guard mappedHoleCount > 0 else {
            return nil
        }

        let source = CourseGeometrySource(rawValue: activeGeometry.sourceRawValue)?.title ?? activeGeometry.sourceName
        return "\(source): \(mappedHoleCount) mapped \(mappedHoleCount == 1 ? "hole" : "holes")"
    }

    private var compactGeometryTitle: String {
        if viewModel.isRefreshingGeometry {
            return "OSM..."
        }

        guard let activeGeometry else {
            return "OSM"
        }

        let mappedHoleCount = mappedHoleCount(for: activeGeometry)
        return mappedHoleCount > 0 ? "OSM \(mappedHoleCount)" : "OSM"
    }

    private var currentHoleUserMappedFeaturePoints: [CourseMapFeaturePoint] {
        courseGeometries
            .flatMap(\.holes)
            .filter { $0.number == viewModel.targetHoleNumber }
            .flatMap(\.featurePoints)
            .filter { !$0.kind.isStickyHoleAnchor && $0.source == .userMapped }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack(alignment: .bottomTrailing) {
            MapReader { proxy in
                Map(position: $viewModel.position, interactionModes: .all) {
                    Marker(viewModel.course.courseName, coordinate: viewModel.course.coordinate)
                    UserAnnotation()

                    if let measuredCoordinate = viewModel.measuredCoordinate {
                        Annotation("Measured Point", coordinate: measuredCoordinate, anchor: .center) {
                            CourseMapMeasuredPointAnnotation(
                                viewModel: viewModel,
                                isDeleteVisible: $isMeasuredPointDeleteVisible
                            )
                        }
                    }

                    if let teeBoxCoordinate = viewModel.teeBoxCoordinate {
                        Annotation("", coordinate: teeBoxCoordinate, anchor: .bottom) {
                            Button {
                                viewModel.selectMapInfo(title: viewModel.teeBoxTitle(for: viewModel.targetHoleNumber), coordinate: teeBoxCoordinate)
                            } label: {
                                CourseMapHoleMarkerView(marker: CourseMapHoleMarker(
                                    id: "active-tee-\(viewModel.targetHoleNumber)",
                                    holeNumber: viewModel.targetHoleNumber,
                                    coordinate: teeBoxCoordinate,
                                    kind: .tee
                                ))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let holePinCoordinate = viewModel.holePinCoordinate {
                        Annotation("", coordinate: holePinCoordinate, anchor: .bottom) {
                            Button {
                                viewModel.selectMapInfo(title: viewModel.greenTitle(for: viewModel.targetHoleNumber), coordinate: holePinCoordinate)
                            } label: {
                                CourseMapHoleMarkerView(marker: CourseMapHoleMarker(
                                    id: "active-pin-\(viewModel.targetHoleNumber)",
                                    holeNumber: viewModel.targetHoleNumber,
                                    coordinate: holePinCoordinate,
                                    kind: .pin
                                ))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(mappedTeeMarkers) { marker in
                        Annotation("", coordinate: marker.coordinate, anchor: .bottom) {
                            Button {
                                viewModel.selectTeeBoxMarker(holeNumber: marker.holeNumber, geometries: courseGeometries, modelContext: modelContext)
                            } label: {
                                CourseMapHoleMarkerView(marker: marker)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(mappedPinMarkers) { marker in
                        Annotation("", coordinate: marker.coordinate, anchor: .bottom) {
                            Button {
                                viewModel.selectPinMarker(holeNumber: marker.holeNumber, geometries: courseGeometries, modelContext: modelContext)
                            } label: {
                                CourseMapHoleMarkerView(marker: marker)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(mappedFeaturePoints) { featurePoint in
                        Annotation("", coordinate: featurePoint.coordinate, anchor: .center) {
                            Button {
                                viewModel.selectMapInfo(title: featurePoint.markerTitle, coordinate: featurePoint.coordinate)
                            } label: {
                                CourseMapFeaturePointMarkerView(featurePoint: featurePoint)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let courseToMeasuredCoordinates = viewModel.courseToMeasuredCoordinates {
                        MapPolyline(coordinates: courseToMeasuredCoordinates)
                            .stroke(BigForeDesign.Palette.distanceLine, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }

                    if let nextHoleTransitionCoordinates = viewModel.nextHoleTransitionCoordinates(from: courseGeometries) {
                        MapPolyline(coordinates: nextHoleTransitionCoordinates)
                            .stroke(BigForeDesign.Palette.transitionLine.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }

                    if let teeToHolePinCoordinates = viewModel.teeToHolePinCoordinates {
                        MapPolyline(coordinates: teeToHolePinCoordinates)
                            .stroke(BigForeDesign.Palette.setupLine, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                    }

                    if let shotLocationToHolePinCoordinates = viewModel.shotLocationToHolePinCoordinates {
                        MapPolyline(coordinates: shotLocationToHolePinCoordinates)
                            .stroke(BigForeDesign.Palette.shot.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }

                    if let shotStartCoordinate = viewModel.shotStartCoordinate {
                        Annotation("Shot Start", coordinate: shotStartCoordinate, anchor: .center) {
                            Button {
                                viewModel.selectMapInfo(title: "Shot start", coordinate: shotStartCoordinate)
                            } label: {
                                CourseMapSymbolMarker(systemImage: "figure.golf", tint: BigForeDesign.Palette.tee)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let shotEndCoordinate = viewModel.shotEndCoordinate {
                        Annotation("Ball", coordinate: shotEndCoordinate, anchor: .center) {
                            Button {
                                viewModel.selectMapInfo(title: "Ball", coordinate: shotEndCoordinate)
                            } label: {
                                CourseMapSymbolMarker(systemImage: "smallcircle.filled.circle", tint: BigForeDesign.Palette.ball)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(viewModel.shotMarkers) { shotMarker in
                        Annotation("Shot \(shotMarker.shotNumber)", coordinate: shotMarker.ballCoordinate, anchor: .center) {
                            Button {
                                viewModel.selectShotMarker(id: shotMarker.id)
                            } label: {
                                CourseMapShotBallMarkerView(
                                    shotNumber: shotMarker.shotNumber,
                                    isSelected: shotMarker.id == viewModel.selectedShotMarkerID
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Shot \(shotMarker.shotNumber) ball marker")
                        }
                    }

                    if let shotMeasurementCoordinates = viewModel.shotMeasurementCoordinates {
                        MapPolyline(coordinates: shotMeasurementCoordinates)
                            .stroke(BigForeDesign.Palette.shotLine, lineWidth: 3)
                    }

                    if let selectedMapInfo = viewModel.selectedMapInfo {
                        Annotation("", coordinate: selectedMapInfo.coordinate, anchor: .bottom) {
                            CourseMapSelectedInfoCard(viewModel: viewModel)
                                .offset(y: -34)
                        }
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
                        isMeasuredPointDeleteVisible = false
                        viewModel.handleMapTap(at: coordinate, modelContext: modelContext)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            CourseMapDistanceHUD(viewModel: viewModel)
                .padding(.top, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)

            if isControlPanelExpanded {
                CourseMapControlPanel(
                    viewModel: viewModel,
                    modelContext: modelContext,
                    courseGeometries: courseGeometries,
                    activeGeometry: activeGeometry,
                    geometrySummaryText: geometrySummaryText,
                    currentHoleUserMappedFeaturePoints: currentHoleUserMappedFeaturePoints,
                    hasUserMappedTee: userMappedStickyAnchor(kind: .teeBox) != nil,
                    hasUserMappedPin: userMappedStickyAnchor(kind: .greenPin) != nil,
                    isDistancesExpanded: $isDistancesExpanded,
                    isSaveTargetExpanded: $isSaveTargetExpanded,
                    onCollapse: collapseControlPanel
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded(handleControlPanelDrag)
                )
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                CourseMapCollapsedActionButtons(
                    viewModel: viewModel,
                    modelContext: modelContext,
                    onExpand: expandControlPanel
                )
                .padding(.trailing, 16)
                .padding(.bottom, 82)
                .transition(.scale.combined(with: .opacity))
            }

            CourseMapBottomLeadingControls(
                viewModel: viewModel,
                modelContext: modelContext,
                courseGeometries: courseGeometries,
                activeGeometry: activeGeometry,
                geometrySummaryText: geometrySummaryText,
                compactGeometryTitle: compactGeometryTitle
            )
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
            focusInitialRoundHoleIfNeeded()
            viewModel.requestLocationAccess()
        }
        .onChange(of: courseGeometries.map(\.updatedAt)) {
            viewModel.applyStoredHoleSetup(from: courseGeometries)
            focusInitialRoundHoleIfNeeded()
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

    private func focusInitialRoundHoleIfNeeded() {
        guard !hasFocusedInitialRoundHole,
              viewModel.round != nil,
              !courseGeometries.isEmpty else {
            return
        }

        viewModel.focusSelectedHole(from: courseGeometries)
        hasFocusedInitialRoundHole = true
    }

    private func handleControlPanelDrag(_ value: DragGesture.Value) {
        let verticalMovement = value.translation.height
        let horizontalMovement = abs(value.translation.width)
        guard verticalMovement > 50, verticalMovement > horizontalMovement else {
            return
        }

        collapseControlPanel()
    }

    private func mappedHoleCount(for geometry: CourseGeometry) -> Int {
        geometry.holes.filter { hole in
            hole.greenCenterLatitude != nil || !hole.featurePoints.isEmpty
        }.count
    }

    private func userMappedStickyAnchor(kind: CourseMapFeatureKind) -> CourseMapFeaturePoint? {
        courseGeometries
            .flatMap(\.holes)
            .filter { $0.number == viewModel.targetHoleNumber }
            .flatMap(\.featurePoints)
            .first { $0.kind == kind && $0.source == .userMapped }
    }

    private func preferredFeaturePoint(kind: CourseMapFeatureKind, in featurePoints: [CourseMapFeaturePoint]) -> CourseMapFeaturePoint? {
        let sourcePriority: [CourseGeometrySource] = [.userMapped, .licensedProvider, .openStreetMap, .manualImport]

        for source in sourcePriority {
            if let featurePoint = featurePoints.first(where: { $0.kind == kind && $0.source == source }) {
                return featurePoint
            }
        }

        return nil
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

