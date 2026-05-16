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
    @Query(sort: \GolfClub.displayOrder) private var golfClubs: [GolfClub]
    @State private var viewModel: CourseMapViewModel
    @State private var isMeasuredPointDeleteVisible = false
    @State private var hasFocusedInitialRoundHole = false
    @AppStorage("courseMap.isControlPanelExpanded") private var isControlPanelExpanded = true
    @AppStorage("courseMap.isDistancesExpanded") private var isDistancesExpanded = true
    @State private var mapLandscapeShowsAllPlayers = false
    @State private var mapLandscapeShowsMetrics = true

    init(course: CourseMapPoint, currentHoleNumber: Int? = nil, round: GolfRound? = nil, focusedPlayerID: UUID? = nil) {
        _viewModel = State(initialValue: CourseMapViewModel(
            course: course,
            currentHoleNumber: currentHoleNumber,
            round: round,
            focusedPlayerID: focusedPlayerID
        ))
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

    private var activeGolfClubs: [GolfClub] {
        golfClubs.filter(\.isActive)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        GeometryReader { geometry in
            Group {
                if let round = viewModel.round, geometry.size.width > geometry.size.height {
                    ScorecardLandscapeScorecardView(
                        round: round,
                        showsAllPlayers: $mapLandscapeShowsAllPlayers,
                        showsMetrics: $mapLandscapeShowsMetrics
                    )
                } else {
                    ZStack(alignment: .bottomTrailing) {
            MapReader { proxy in
                Map(position: $viewModel.position, interactionModes: .all) {
                    Marker(viewModel.course.courseName, coordinate: viewModel.course.coordinate)
                    UserAnnotation()

                    if let teeBoxCoordinate = viewModel.teeBoxCoordinate {
                        Annotation("", coordinate: teeBoxCoordinate, anchor: .bottom) {
                            Button {
                                viewModel.selectMapInfo(
                                    title: viewModel.teeBoxTitle(for: viewModel.targetHoleNumber),
                                    coordinate: teeBoxCoordinate,
                                    cardPlacement: .trailing
                                )
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

                    ForEach(Array(viewModel.savedShotLineSegments.enumerated()), id: \.offset) { _, segment in
                        MapPolyline(coordinates: segment)
                            .stroke(BigForeDesign.Palette.shotLine.opacity(0.82), style: StrokeStyle(lineWidth: 3, dash: [5, 5]))
                    }

                    if let landingTarget = viewModel.clubLandingTarget(from: activeGolfClubs, geometries: courseGeometries) {
                        MapPolyline(coordinates: landingTarget.lineCoordinates)
                            .stroke(BigForeDesign.Palette.hazard, style: StrokeStyle(lineWidth: 3, dash: [3, 6]))

                        Annotation(landingTarget.title, coordinate: landingTarget.coordinate, anchor: .center) {
                            CourseMapSymbolMarker(systemImage: "scope", tint: .red, size: 34)
                                .accessibilityLabel(landingTarget.title)
                        }
                    }

                    if let shotStartCoordinate = viewModel.shotStartCoordinate {
                        Annotation(viewModel.shotEndCoordinate == nil ? "Shot Start" : "", coordinate: shotStartCoordinate, anchor: .center) {
                            Button {
                                viewModel.selectMapInfo(title: "Shot start", coordinate: shotStartCoordinate)
                            } label: {
                                CourseMapSymbolMarker(systemImage: "figure.golf", tint: BigForeDesign.Palette.tee)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Shot start")
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
                        Annotation("", coordinate: selectedMapInfo.coordinate, anchor: selectedMapInfo.cardPlacement.annotationAnchor) {
                            CourseMapSelectedInfoCard(viewModel: viewModel, modelContext: modelContext)
                                .offset(selectedMapInfo.cardPlacement.cardOffset)
                        }
                    }
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControlVisibility(.hidden)
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

            CourseMapVenueChip(courseMapViewModel: viewModel)
                .padding(.top, -54)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            CourseMapTopTrailingControls(viewModel: viewModel)
                .padding(.top, 16)
                .padding(.trailing, BigForeDesign.Spacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            CourseMapDistanceMetricStack(viewModel: viewModel, modelContext: modelContext, activeGolfClubs: activeGolfClubs, courseGeometries: courseGeometries)
                .padding(.top, 96)
                .padding(.trailing, BigForeDesign.Spacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            if isControlPanelExpanded {
                CourseMapControlPanel(
                    viewModel: viewModel,
                    modelContext: modelContext,
                    courseGeometries: courseGeometries,
                    activeGeometry: activeGeometry,
                    geometrySummaryText: geometrySummaryText,
                    activeGolfClubs: activeGolfClubs,
                    hasUserMappedTee: userMappedStickyAnchor(kind: .teeBox) != nil,
                    hasUserMappedPin: userMappedStickyAnchor(kind: .greenPin) != nil,
                    isDistancesExpanded: $isDistancesExpanded,
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
                activeGolfClubs: activeGolfClubs
            )
                .padding(.leading)
                .padding(.bottom, isControlPanelExpanded ? 456 : 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
            }
        }
        .animation(.snappy, value: isControlPanelExpanded)
        .animation(.snappy, value: isDistancesExpanded)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
            viewModel.applyStoredHoleSetup(from: courseGeometries)
            viewModel.applyPersistedShotRecords()
            focusInitialRoundHoleIfNeeded()
            viewModel.requestLocationAccess()
        }
        .onChange(of: courseGeometries.map(\.updatedAt)) {
            viewModel.applyStoredHoleSetup(from: courseGeometries)
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
            focusInitialRoundHoleIfNeeded()
        }
        .onChange(of: viewModel.targetHoleNumber) {
            viewModel.applyStoredHoleSetup(from: courseGeometries)
            viewModel.applyPersistedShotRecords()
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: activeGolfClubs.map(\.id)) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: viewModel.shotStartCoordinate?.latitude) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: viewModel.shotStartCoordinate?.longitude) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: viewModel.shotEndCoordinate?.latitude) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: viewModel.shotEndCoordinate?.longitude) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: viewModel.teeBoxCoordinate?.latitude) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: viewModel.teeBoxCoordinate?.longitude) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: viewModel.holePinCoordinate?.latitude) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
        }
        .onChange(of: viewModel.holePinCoordinate?.longitude) {
            viewModel.selectWoodyClub(from: activeGolfClubs, geometries: courseGeometries)
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

private extension CourseMapInfoCardPlacement {
    var annotationAnchor: UnitPoint {
        switch self {
        case .above:
            .bottom
        case .trailing:
            .leading
        }
    }

    var cardOffset: CGSize {
        switch self {
        case .above:
            CGSize(width: 0, height: -34)
        case .trailing:
            CGSize(width: 26, height: -8)
        }
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

