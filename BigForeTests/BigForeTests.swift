import CoreLocation
import SwiftData
import Testing
@testable import BigFore

@MainActor
struct BigForeTests {
    @Test func scoringCalculatesStrokePlayAndStablefordTotals() {
        let player = RoundPlayer(
            name: "Grant",
            displayOrder: 0,
            scores: [
                HoleScore(holeNumber: 1, par: 4, strokes: 4),
                HoleScore(holeNumber: 2, par: 5, strokes: 4),
                HoleScore(holeNumber: 3, par: 3, strokes: 0)
            ]
        )

        let scoring = RoundScoring()

        #expect(scoring.completedHoles(for: player) == 2)
        #expect(scoring.totalStrokes(for: player) == 8)
        #expect(scoring.scoreRelativeToPar(for: player) == -1)
        #expect(scoring.stablefordPoints(for: player) == 5)
        #expect(scoring.relativeText(-1) == "-1")
        #expect(scoring.relativeText(0) == "E")
        #expect(scoring.relativeText(2) == "+2")
    }

    @Test func scorecardScoreResultCategorizesRelativeScores() {
        #expect(ScorecardScoreResult(relativeToPar: -4) == .albatross)
        #expect(ScorecardScoreResult(relativeToPar: -3) == .albatross)
        #expect(ScorecardScoreResult(relativeToPar: -2) == .eagle)
        #expect(ScorecardScoreResult(relativeToPar: -1) == .birdie)
        #expect(ScorecardScoreResult(relativeToPar: 0) == .par)
        #expect(ScorecardScoreResult(relativeToPar: 1) == .bogey)
        #expect(ScorecardScoreResult(relativeToPar: 2) == .doubleBogeyOrWorse)
        #expect(ScorecardScoreResult(relativeToPar: 4) == .doubleBogeyOrWorse)
    }

    @Test func distanceCalculatorConvertsCoordinatesToRoundedYards() {
        let calculator = DistanceCalculator()
        let start = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let samePoint = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let nearbyPoint = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        #expect(calculator.yards(from: start, to: samePoint) == 0)
        #expect((115...125).contains(calculator.yards(from: start, to: nearbyPoint)))
        #expect(calculator.formattedYards(from: start, to: samePoint) == "0 yds")
    }

    @Test func locationServiceReportsAccuracyStatus() {
        let locationService = LocationService()
        locationService.authorizationStatus = .authorizedWhenInUse

        locationService.currentLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0),
            altitude: 0,
            horizontalAccuracy: 12,
            verticalAccuracy: 12,
            timestamp: .now
        )

        #expect(locationService.currentAccuracyText == "+/- 13 yds")
        #expect(locationService.locationStatusText == "GPS accuracy: +/- 13 yds.")

        locationService.currentLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0),
            altitude: 0,
            horizontalAccuracy: 80,
            verticalAccuracy: 12,
            timestamp: .now
        )

        #expect(locationService.locationStatusText == "Low GPS accuracy: +/- 87 yds.")
    }

    @Test func courseMapPointBuildsFromSavedCourseAndRoundCoordinates() throws {
        let savedCourse = GolfCourse(
            externalID: 314,
            clubName: "Example Club",
            courseName: "Example Course",
            latitude: 33.75,
            longitude: -84.39
        )
        let savedPoint = try #require(CourseMapPoint(savedCourse: savedCourse))
        let round = GolfRound(
            courseExternalID: 314,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.76,
            courseLongitude: -84.40,
            teeName: "Blue",
            teeGender: "male"
        )
        let roundPoint = try #require(CourseMapPoint(round: round))

        #expect(savedPoint.id == 314)
        #expect(savedPoint.latitude == 33.75)
        #expect(savedPoint.longitude == -84.39)
        #expect(roundPoint.latitude == 33.76)
        #expect(roundPoint.longitude == -84.40)
    }

    @Test func courseMapViewModelTracksShotDistanceFromCurrentLocation() throws {
        let locationService = LocationService()
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course, locationService: locationService)

        locationService.currentLocation = CLLocation(latitude: 33.0, longitude: -84.0)
        viewModel.startShotFromCurrentLocation()

        #expect(viewModel.isTrackingShot)
        #expect(viewModel.shotEndCoordinate == nil)

        locationService.currentLocation = CLLocation(latitude: 33.001, longitude: -84.0)
        let liveDistance = try #require(viewModel.shotDistanceText)

        #expect(liveDistance.hasSuffix(" yds"))

        viewModel.markShotEndAtCurrentLocation()

        #expect(viewModel.isTrackingShot == false)
        #expect(viewModel.shotEndCoordinate != nil)
        #expect(viewModel.shotDistanceText == liveDistance)

        viewModel.clearShotMeasurement()

        #expect(viewModel.shotStartCoordinate == nil)
        #expect(viewModel.shotEndCoordinate == nil)
        #expect(viewModel.shotDistanceText == nil)
    }

    @Test func courseMapViewModelTracksShotDistanceBetweenTappedPoints() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)

        viewModel.measurePoint(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        viewModel.startShotFromMeasuredPoint()
        viewModel.measurePoint(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))
        viewModel.markShotEndAtMeasuredPoint()

        let shotDistance = try #require(viewModel.shotDistanceText)

        #expect(viewModel.isTrackingShot == false)
        #expect(viewModel.shotStartCoordinate != nil)
        #expect(viewModel.shotEndCoordinate != nil)
        #expect(shotDistance.hasSuffix(" yds"))
    }

    @Test func courseMapViewModelSelectionModeSetsManualAnchors() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let measurement = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0001)
        let teeBox = CLLocationCoordinate2D(latitude: 33.0002, longitude: -84.0002)
        let holePin = CLLocationCoordinate2D(latitude: 33.0012, longitude: -84.0002)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0003, longitude: -84.0003)
        let ball = CLLocationCoordinate2D(latitude: 33.0008, longitude: -84.0003)

        viewModel.selectionMode = .measurementPin
        viewModel.selectMapLocation(at: measurement)
        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: teeBox)
        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: holePin)
        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: shotStart)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: ball)

        #expect(viewModel.measuredCoordinate?.latitude == measurement.latitude)
        #expect(viewModel.teeBoxCoordinate?.latitude == teeBox.latitude)
        #expect(viewModel.holePinCoordinate?.latitude == holePin.latitude)
        #expect(viewModel.shotStartCoordinate?.latitude == shotStart.latitude)
        #expect(viewModel.shotEndCoordinate?.latitude == ball.latitude)
        #expect(viewModel.isTrackingShot == false)
        #expect(viewModel.selectionMode == .inactive)
    }

    @Test func courseMapViewModelUndoesPlacedMapPinsInReverseOrder() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let measurement = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0001)
        let teeBox = CLLocationCoordinate2D(latitude: 33.0002, longitude: -84.0002)
        let holePin = CLLocationCoordinate2D(latitude: 33.0012, longitude: -84.0002)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0003, longitude: -84.0003)
        let ball = CLLocationCoordinate2D(latitude: 33.0008, longitude: -84.0003)

        viewModel.selectionMode = .measurementPin
        viewModel.selectMapLocation(at: measurement)
        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: teeBox)
        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: holePin)
        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: shotStart)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: ball)

        #expect(viewModel.canUndoLastPin)

        viewModel.undoLastPin()
        #expect(viewModel.shotEndCoordinate == nil)
        #expect(viewModel.shotMarkers.isEmpty)
        #expect(viewModel.shotStartCoordinate?.latitude == shotStart.latitude)

        viewModel.undoLastPin()
        #expect(viewModel.shotStartCoordinate == nil)
        #expect(viewModel.holePinCoordinate?.latitude == holePin.latitude)

        viewModel.undoLastPin()
        #expect(viewModel.holePinCoordinate == nil)
        #expect(viewModel.teeBoxCoordinate?.latitude == teeBox.latitude)

        viewModel.undoLastPin()
        #expect(viewModel.teeBoxCoordinate == nil)
        #expect(viewModel.measuredCoordinate?.latitude == measurement.latitude)

        viewModel.undoLastPin()
        #expect(viewModel.measuredCoordinate == nil)
        #expect(viewModel.canUndoLastPin == false)
    }

    @Test func courseMapViewModelTapModesDeactivateAfterPlacement() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let firstTee = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let secondTee = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: firstTee)
        viewModel.selectMapLocation(at: secondTee)

        #expect(viewModel.selectionMode == .inactive)
        #expect(viewModel.teeBoxCoordinate?.latitude == firstTee.latitude)
    }

    @Test func courseMapViewModelActionStripButtonsSetTapModes() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course, currentHoleNumber: 4)

        viewModel.errorMessage = "Previous error"
        viewModel.setMeasurementPinTapMode()
        #expect(viewModel.selectionMode == .measurementPin)
        #expect(viewModel.statusMessage == "Tap the map to drop a measurement pin.")
        #expect(viewModel.errorMessage == nil)

        viewModel.setShotStartTapMode()
        #expect(viewModel.selectionMode == .shotStart)
        #expect(viewModel.statusMessage == "Tap the map to set shot start for Hole 4.")
        #expect(viewModel.errorMessage == nil)

        viewModel.setShotBallTapMode()
        #expect(viewModel.selectionMode == .shotBall)
        #expect(viewModel.statusMessage == "Tap the map to set ball location for Hole 4.")

        viewModel.setTeeBoxTapMode()
        #expect(viewModel.selectionMode == .teeBox)
        #expect(viewModel.statusMessage == "Tap the map to save Tee 4.")

        viewModel.setHolePinTapMode()
        #expect(viewModel.selectionMode == .holePin)
        #expect(viewModel.statusMessage == "Tap the map to save Pin 4.")
    }

    @Test func courseMapViewModelTeePinModesFrameHoleLineWithPinAtTop() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course, currentHoleNumber: 15)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let pin = CLLocationCoordinate2D(latitude: 33.0, longitude: -83.99)
        let geometry = CourseGeometry(
            courseExternalID: 42,
            source: .openStreetMap,
            sourceName: "OpenStreetMap",
            holes: [
                HoleGeometry(
                    number: 15,
                    greenCenterLatitude: pin.latitude,
                    greenCenterLongitude: pin.longitude,
                    featurePoints: [
                        CourseMapFeaturePoint(
                            kind: .teeBox,
                            label: "OSM Tee 15",
                            latitude: tee.latitude,
                            longitude: tee.longitude,
                            source: .openStreetMap
                        )
                    ]
                )
            ]
        )

        viewModel.setTeeBoxTapMode(geometries: [geometry])

        #expect(viewModel.selectionMode == .teeBox)
        #expect(viewModel.teeBoxCoordinate?.latitude == tee.latitude)
        #expect(viewModel.holePinCoordinate?.longitude == pin.longitude)
        #expect(abs(viewModel.cameraCenter.longitude - ((tee.longitude + pin.longitude) / 2)) < 0.000001)
        #expect((85...95).contains(viewModel.cameraHeading))
        #expect(viewModel.cameraPitch == 55)

        viewModel.setHolePinTapMode(geometries: [geometry])

        #expect(viewModel.selectionMode == .holePin)
        #expect((85...95).contains(viewModel.cameraHeading))
        #expect(viewModel.cameraPitch == 55)

        viewModel.selectHole(15, geometries: [geometry])

        #expect((85...95).contains(viewModel.cameraHeading))
        #expect(viewModel.cameraPitch == 55)
    }

    @Test func courseMapViewModelBuildsFaintNextHoleTransitionLineTarget() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course, currentHoleNumber: 9)
        let holeNinePin = CLLocationCoordinate2D(latitude: 33.009, longitude: -84.0)
        let holeTenTee = CLLocationCoordinate2D(latitude: 33.010, longitude: -84.001)
        let geometry = CourseGeometry(
            courseExternalID: 42,
            source: .openStreetMap,
            sourceName: "OpenStreetMap",
            holes: [
                HoleGeometry(number: 9, greenCenterLatitude: holeNinePin.latitude, greenCenterLongitude: holeNinePin.longitude),
                HoleGeometry(
                    number: 10,
                    featurePoints: [
                        CourseMapFeaturePoint(
                            kind: .teeBox,
                            label: "OSM Tee 10",
                            latitude: holeTenTee.latitude,
                            longitude: holeTenTee.longitude,
                            source: .openStreetMap
                        )
                    ]
                )
            ]
        )

        viewModel.applyStoredHoleSetup(from: [geometry])
        let transitionCoordinates = try #require(viewModel.nextHoleTransitionCoordinates(from: [geometry]))

        #expect(transitionCoordinates.count == 2)
        #expect(transitionCoordinates.first?.latitude == holeNinePin.latitude)
        #expect(transitionCoordinates.last?.latitude == holeTenTee.latitude)
    }

    @Test func courseMapViewModelSelectingHoleFocusesStickyTeePinRegion() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let tee = CLLocationCoordinate2D(latitude: 33.010, longitude: -84.010)
        let pin = CLLocationCoordinate2D(latitude: 33.014, longitude: -84.006)
        let geometry = CourseGeometry(
            courseExternalID: 42,
            source: .userMapped,
            sourceName: "User Mapped",
            holes: [
                HoleGeometry(
                    number: 2,
                    featurePoints: [
                        CourseMapFeaturePoint(kind: .teeBox, label: "Tee 2", latitude: tee.latitude, longitude: tee.longitude),
                        CourseMapFeaturePoint(kind: .greenPin, label: "Pin 2", latitude: pin.latitude, longitude: pin.longitude)
                    ]
                )
            ]
        )

        viewModel.selectHole(2, geometries: [geometry])

        #expect(viewModel.targetHoleNumber == 2)
        #expect(viewModel.teeBoxCoordinate?.latitude == tee.latitude)
        #expect(viewModel.holePinCoordinate?.latitude == pin.latitude)
        #expect(viewModel.cameraCenter.latitude == (tee.latitude + pin.latitude) / 2)
        #expect(viewModel.cameraCenter.longitude == (tee.longitude + pin.longitude) / 2)
    }

    @Test func courseMapViewModelSelectingHoleFallsBackToPreviousHolePin() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let previousPin = CLLocationCoordinate2D(latitude: 33.020, longitude: -84.020)
        let geometry = CourseGeometry(
            courseExternalID: 42,
            source: .userMapped,
            sourceName: "User Mapped",
            holes: [
                HoleGeometry(
                    number: 2,
                    featurePoints: [
                        CourseMapFeaturePoint(
                            kind: .greenPin,
                            label: "Pin 2",
                            latitude: previousPin.latitude,
                            longitude: previousPin.longitude
                        )
                    ]
                )
            ]
        )

        viewModel.selectHole(3, geometries: [geometry])

        #expect(viewModel.targetHoleNumber == 3)
        #expect(viewModel.teeBoxCoordinate == nil)
        #expect(viewModel.holePinCoordinate == nil)
        #expect(viewModel.cameraCenter.latitude == previousPin.latitude)
        #expect(viewModel.cameraCenter.longitude == previousPin.longitude)
    }

    @Test func courseMapViewModelSelectingHoleSkipsMissingPreviousPin() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let holeTwoTee = CLLocationCoordinate2D(latitude: 33.030, longitude: -84.030)
        let holeOnePin = CLLocationCoordinate2D(latitude: 33.010, longitude: -84.010)
        let geometry = CourseGeometry(
            courseExternalID: 42,
            source: .userMapped,
            sourceName: "User Mapped",
            holes: [
                HoleGeometry(
                    number: 1,
                    featurePoints: [
                        CourseMapFeaturePoint(
                            kind: .greenPin,
                            label: "Pin 1",
                            latitude: holeOnePin.latitude,
                            longitude: holeOnePin.longitude
                        )
                    ]
                ),
                HoleGeometry(
                    number: 2,
                    featurePoints: [
                        CourseMapFeaturePoint(
                            kind: .teeBox,
                            label: "Tee 2",
                            latitude: holeTwoTee.latitude,
                            longitude: holeTwoTee.longitude
                        )
                    ]
                )
            ]
        )

        viewModel.selectHole(3, geometries: [geometry])

        #expect(viewModel.cameraCenter.latitude == holeOnePin.latitude)
        #expect(viewModel.cameraCenter.longitude == holeOnePin.longitude)
    }

    @Test func courseMapViewModelSelectingHoleKeepsSelectedHolePinPriority() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let previousPin = CLLocationCoordinate2D(latitude: 33.020, longitude: -84.020)
        let selectedPin = CLLocationCoordinate2D(latitude: 33.040, longitude: -84.040)
        let geometry = CourseGeometry(
            courseExternalID: 42,
            source: .userMapped,
            sourceName: "User Mapped",
            holes: [
                HoleGeometry(
                    number: 2,
                    featurePoints: [
                        CourseMapFeaturePoint(
                            kind: .greenPin,
                            label: "Pin 2",
                            latitude: previousPin.latitude,
                            longitude: previousPin.longitude
                        )
                    ]
                ),
                HoleGeometry(
                    number: 3,
                    featurePoints: [
                        CourseMapFeaturePoint(
                            kind: .greenPin,
                            label: "Pin 3",
                            latitude: selectedPin.latitude,
                            longitude: selectedPin.longitude
                        )
                    ]
                )
            ]
        )

        viewModel.selectHole(3, geometries: [geometry])

        #expect(viewModel.holePinCoordinate?.latitude == selectedPin.latitude)
        #expect(viewModel.cameraCenter.latitude == selectedPin.latitude)
        #expect(viewModel.cameraCenter.longitude == selectedPin.longitude)
    }

    @Test func courseMapViewModelSelectingHoleFallsBackToShotLineThenCourseCenter() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course, currentHoleNumber: 2)
        let shotStart = CLLocationCoordinate2D(latitude: 33.010, longitude: -84.010)
        let ball = CLLocationCoordinate2D(latitude: 33.014, longitude: -84.006)

        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: shotStart)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: ball)
        viewModel.moveToHole(1)

        viewModel.selectHole(2, geometries: [])

        #expect(viewModel.cameraCenter.latitude == (shotStart.latitude + ball.latitude) / 2)
        #expect(viewModel.cameraCenter.longitude == (shotStart.longitude + ball.longitude) / 2)

        viewModel.selectHole(3, geometries: [])

        #expect(viewModel.cameraCenter.latitude == course.latitude)
        #expect(viewModel.cameraCenter.longitude == course.longitude)
    }

    @Test func startRoundViewModelDefaultsFirstPlayerToGp() {
        let course = RoundSetupCourse(
            externalID: 42,
            clubName: "Example Club",
            courseName: "Example Course",
            latitude: nil,
            longitude: nil
        )
        let tee = RoundSetupTee(
            gender: "male",
            name: "Blue",
            totalYards: nil,
            parTotal: nil,
            holes: [RoundSetupHole(number: 1, par: 4, yardage: nil, handicap: nil)]
        )
        let viewModel = StartRoundViewModel(course: course, tee: tee)

        #expect(viewModel.playerNames == ["Gp."])

        viewModel.removePlayers(at: IndexSet(integer: 0))

        #expect(viewModel.playerNames == ["Gp."])

        viewModel.newPlayerName = "Alex"
        viewModel.addPlayer()

        #expect(viewModel.playerNames == ["Gp.", "Alex"])
    }

    @Test func courseMapViewModelReportsTeeToHolePinDistance() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)

        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))

        let teeDistance = try #require(viewModel.teeToHolePinDistanceText)

        #expect(teeDistance.hasSuffix(" yds"))
        #expect(viewModel.teeToHolePinCoordinates?.count == 2)
    }

    @Test func courseMapViewModelManualShotSelectionOverridesGPS() throws {
        let locationService = LocationService()
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course, locationService: locationService)
        let manualStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let manualBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let holePin = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        locationService.currentLocation = CLLocation(latitude: 33.0, longitude: -84.0)
        viewModel.startShotFromCurrentLocation()
        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: manualStart)
        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: holePin)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: manualBall)

        let shotDistance = try #require(viewModel.shotDistanceText)
        let ballToPinDistance = try #require(viewModel.shotLocationToHolePinDistanceText)
        locationService.currentLocation = CLLocation(latitude: 33.004, longitude: -84.0)

        #expect(viewModel.shotStartCoordinate?.latitude == manualStart.latitude)
        #expect(viewModel.shotEndCoordinate?.latitude == manualBall.latitude)
        #expect(viewModel.shotDistanceText == shotDistance)
        #expect(viewModel.shotLocationToHolePinLabel == "Ball to pin")
        #expect(viewModel.shotLocationToHolePinDistanceText == ballToPinDistance)
    }

    @Test func courseMapViewModelPersistsStickyTeeAndPinFromMapTaps() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course, currentHoleNumber: 3)
        let teeBox = CLLocationCoordinate2D(latitude: 33.0002, longitude: -84.0002)
        let providerPin = CLLocationCoordinate2D(latitude: 33.0099, longitude: -84.0099)
        let userPin = CLLocationCoordinate2D(latitude: 33.0012, longitude: -84.0002)

        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: teeBox, modelContext: modelContext)
        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: userPin, modelContext: modelContext)

        let geometries = try modelContext.fetch(FetchDescriptor<CourseGeometry>())
        let geometry = try #require(geometries.first)
        let hole = try #require(geometry.holes.first { $0.number == 3 })
        hole.greenCenterLatitude = providerPin.latitude
        hole.greenCenterLongitude = providerPin.longitude
        try modelContext.save()

        let restoredViewModel = CourseMapViewModel(course: course, currentHoleNumber: 3)
        restoredViewModel.applyStoredHoleSetup(from: geometries)

        #expect(hole.featurePoints.filter { $0.kind == .teeBox && $0.source == .userMapped }.count == 1)
        #expect(hole.featurePoints.filter { $0.kind == .greenPin && $0.source == .userMapped }.count == 1)
        #expect(restoredViewModel.teeBoxCoordinate?.latitude == teeBox.latitude)
        #expect(restoredViewModel.holePinCoordinate?.latitude == userPin.latitude)
    }

    @Test func courseMapViewModelStartsNextShotFromMarkedBall() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: shotStart)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: ball)

        #expect(viewModel.shotMarkers.count == 1)
        #expect(viewModel.shotMarkers.first?.ballCoordinate.latitude == ball.latitude)

        viewModel.startNextShotFromBall()

        #expect(viewModel.shotStartCoordinate?.latitude == ball.latitude)
        #expect(viewModel.shotEndCoordinate == nil)
        #expect(viewModel.selectionMode == .shotBall)
    }

    @Test func courseMapViewModelDeletesSelectedShotAndUpdatesScore() throws {
        let score = HoleScore(holeNumber: 1, par: 4)
        let player = RoundPlayer(name: "Grant", displayOrder: 0, scores: [score])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            players: [player]
        )
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let course = try #require(CourseMapPoint(round: round))
        let viewModel = CourseMapViewModel(course: course, round: round)

        modelContext.insert(round)
        try modelContext.save()
        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0), modelContext: modelContext)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0), modelContext: modelContext)

        let marker = try #require(viewModel.shotMarkers.first)
        viewModel.selectShotMarker(id: marker.id)
        viewModel.deleteSelectedShotMarker(modelContext: modelContext)

        #expect(viewModel.shotMarkers.isEmpty)
        #expect(viewModel.selectedShotMarkerID == nil)
        #expect(score.strokes == 0)
        #expect(viewModel.statusMessage == "Deleted shot.")
    }

    @Test func courseGeometryEditorDeletesUserMappedAnchorsButKeepsImportedFallback() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let editor = CourseGeometryEditor()
        let userTee = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0001)
        let osmTee = CLLocationCoordinate2D(latitude: 33.0003, longitude: -84.0003)

        _ = try editor.setStickyHoleAnchor(
            courseExternalID: 42,
            holeNumber: 1,
            kind: .teeBox,
            coordinate: userTee,
            modelContext: modelContext
        )
        _ = try editor.importGeometry(
            CourseGeometryImport(
                courseExternalID: 42,
                source: .openStreetMap,
                sourceName: "OpenStreetMap",
                attribution: nil,
                holes: [
                    HoleGeometryImport(
                        number: 1,
                        featurePoints: [
                            CourseGeometryFeatureImport(kind: .teeBox, label: "OSM Tee 1", coordinate: osmTee, sortOrder: 0)
                        ]
                    )
                ]
            ),
            modelContext: modelContext
        )

        try editor.clearStickyHoleAnchor(courseExternalID: 42, holeNumber: 1, kind: .teeBox, modelContext: modelContext)

        let geometry = try #require(try modelContext.fetch(FetchDescriptor<CourseGeometry>()).first)
        let hole = try #require(geometry.holes.first { $0.number == 1 })

        #expect(hole.featurePoints.contains { $0.kind == .teeBox && $0.source == .userMapped } == false)
        #expect(hole.featurePoints.contains { $0.kind == .teeBox && $0.source == .openStreetMap })
    }

    @Test func courseMapViewModelNextShotButtonRequiresMarkedBall() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        #expect(viewModel.canStartNextShotFromBall == false)
        viewModel.startNextShotFromBall()
        #expect(viewModel.shotStartCoordinate == nil)
        #expect(viewModel.selectionMode == .measurementPin)

        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: shotStart)
        #expect(viewModel.canStartNextShotFromBall == false)

        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: ball)
        #expect(viewModel.canStartNextShotFromBall)

        viewModel.startNextShotFromBall()

        #expect(viewModel.canStartNextShotFromBall == false)
        #expect(viewModel.shotStartCoordinate?.latitude == ball.latitude)
        #expect(viewModel.shotEndCoordinate == nil)
        #expect(viewModel.selectionMode == .shotBall)
    }

    @Test func courseMapViewModelSelectsShotMarkerAndUpdatesBallLocation() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let movedBall = CLLocationCoordinate2D(latitude: 33.0014, longitude: -84.0)
        let holePin = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: holePin)
        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: shotStart)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: ball)

        let marker = try #require(viewModel.shotMarkers.first)
        viewModel.selectShotMarker(id: marker.id)

        let distanceToPin = try #require(viewModel.selectedShotMarkerDistanceToPinText)

        viewModel.selectionMode = .moveShotBall
        viewModel.selectMapLocation(at: movedBall)

        #expect(distanceToPin.hasSuffix(" yds"))
        #expect(viewModel.shotMarkers.first?.ballCoordinate.latitude == movedBall.latitude)
        #expect(viewModel.shotEndCoordinate?.latitude == movedBall.latitude)
        #expect(viewModel.selectedShotMarkerDistanceToPinText != distanceToPin)
    }

    @Test func courseMapViewModelBuildsAllShotSummariesFromTeePreviousBallAndPin() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let calculator = DistanceCalculator()
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let firstStart = CLLocationCoordinate2D(latitude: 33.0002, longitude: -84.0)
        let firstBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let secondBall = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)
        let pin = CLLocationCoordinate2D(latitude: 33.003, longitude: -84.0)

        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: tee)
        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: pin)
        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: firstStart)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: firstBall)
        viewModel.startNextShotFromBall()
        viewModel.selectMapLocation(at: secondBall)

        let summaries = viewModel.shotSummaries
        let firstSummary = try #require(summaries.first)
        let secondSummary = try #require(summaries.last)

        #expect(summaries.count == 2)
        #expect(firstSummary.distanceFromPreviousText == calculator.formattedYards(from: tee, to: firstBall))
        #expect(secondSummary.distanceFromPreviousText == calculator.formattedYards(from: firstBall, to: secondBall))
        #expect(firstSummary.distanceToPinText == calculator.formattedYards(from: firstBall, to: pin))
        #expect(secondSummary.distanceToPinText == calculator.formattedYards(from: secondBall, to: pin))
    }

    @Test func courseMapViewModelSelectingShotUpdatesCurrentShotAndCamera() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let firstStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let firstBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let secondBall = CLLocationCoordinate2D(latitude: 33.004, longitude: -84.0)

        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: firstStart)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: firstBall)
        viewModel.startNextShotFromBall()
        viewModel.selectMapLocation(at: secondBall)

        let firstMarker = try #require(viewModel.shotMarkers.first)
        viewModel.selectShotMarker(id: firstMarker.id)

        #expect(viewModel.selectedShotMarkerID == firstMarker.id)
        #expect(viewModel.shotStartCoordinate?.latitude == firstStart.latitude)
        #expect(viewModel.shotEndCoordinate?.latitude == firstBall.latitude)
        #expect(viewModel.cameraCenter.latitude != course.latitude)
        #expect(viewModel.shotSummaries.first?.isSelected == true)
    }

    @Test func courseMapViewModelScoreButtonsUpdateCurrentHoleScore() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let score = HoleScore(holeNumber: 1, par: 4)
        let player = RoundPlayer(name: "Grant", displayOrder: 0, scores: [score])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            players: [player]
        )
        let course = try #require(CourseMapPoint(round: round))
        let viewModel = CourseMapViewModel(course: course, round: round)

        modelContext.insert(round)
        try modelContext.save()

        viewModel.incrementSelectedHoleScore(modelContext: modelContext)
        viewModel.incrementSelectedHoleScore(modelContext: modelContext)

        #expect(score.strokes == 2)
        #expect(viewModel.compactHoleScoreText == "S2")
        #expect(viewModel.canDecreaseSelectedHoleScore)

        viewModel.decrementSelectedHoleScore(modelContext: modelContext)

        #expect(score.strokes == 1)

        for _ in 0..<20 {
            viewModel.incrementSelectedHoleScore(modelContext: modelContext)
        }

        #expect(score.strokes == 12)
        #expect(viewModel.canIncreaseSelectedHoleScore == false)
    }

    @Test func courseMapViewModelManualShotsUpdateFirstPlayerHoleScore() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let grantScore = HoleScore(holeNumber: 1, par: 4)
        let alexScore = HoleScore(holeNumber: 1, par: 4)
        let grant = RoundPlayer(name: "Grant", displayOrder: 0, scores: [grantScore])
        let alex = RoundPlayer(name: "Alex", displayOrder: 1, scores: [alexScore])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            players: [alex, grant]
        )
        let course = try #require(CourseMapPoint(round: round))
        let viewModel = CourseMapViewModel(course: course, round: round)

        modelContext.insert(round)
        try modelContext.save()

        viewModel.incrementSelectedHoleScore(modelContext: modelContext)
        viewModel.incrementSelectedHoleScore(modelContext: modelContext)
        viewModel.incrementSelectedHoleScore(modelContext: modelContext)

        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0), modelContext: modelContext)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0), modelContext: modelContext)
        viewModel.startNextShotFromBall()
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0), modelContext: modelContext)

        #expect(viewModel.selectedScoringPlayer?.name == "Grant")
        #expect(grantScore.strokes == 2)
        #expect(alexScore.strokes == 0)
    }

    @Test func courseMapViewModelHandleMapTapSetsMeasurementPin() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let tappedCoordinate = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        viewModel.handleMapTap(at: tappedCoordinate)

        #expect(viewModel.measuredCoordinate?.latitude == tappedCoordinate.latitude)
    }

    @Test func courseMapViewModelDeletingMeasuredPointDisablesMapTapAction() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)

        viewModel.handleMapTap(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))
        viewModel.deleteMeasuredPoint()
        viewModel.handleMapTap(at: CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0))

        #expect(viewModel.measuredCoordinate == nil)
        #expect(viewModel.selectionMode == .inactive)
        #expect(viewModel.statusMessage == "Choose a map action before tapping.")

        viewModel.selectionMode = .measurementPin
        viewModel.handleMapTap(at: CLLocationCoordinate2D(latitude: 33.003, longitude: -84.0))

        #expect(viewModel.measuredCoordinate?.latitude == 33.003)
    }

    @Test func courseMapViewModelSelectedMapInfoUsesCurrentPlayReference() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let pin = CLLocationCoordinate2D(latitude: 33.003, longitude: -84.0)
        let hazard = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: tee)
        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: pin)
        viewModel.selectMapInfo(title: "Bunker 1", coordinate: hazard)

        var summary = try #require(viewModel.selectedMapInfoSummary)
        #expect(summary.referenceDistanceLabel == "Tee to this")
        #expect(summary.referenceDistanceText?.hasSuffix(" yds") == true)
        #expect(summary.pinDistanceText?.hasSuffix(" yds") == true)

        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: tee)
        viewModel.locationService.currentLocation = CLLocation(latitude: 33.0015, longitude: -84.0)
        viewModel.selectMapInfo(title: "Bunker 1", coordinate: hazard)

        summary = try #require(viewModel.selectedMapInfoSummary)
        #expect(summary.referenceDistanceLabel == "GPS to this")

        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: ball)
        viewModel.selectMapInfo(title: "Bunker 1", coordinate: hazard)

        summary = try #require(viewModel.selectedMapInfoSummary)
        #expect(summary.referenceDistanceLabel == "Ball to this")
    }

    @Test func courseMapViewModelAddsParToTeeAndGreenPopupTitles() throws {
        let score = HoleScore(holeNumber: 13, par: 3)
        let player = RoundPlayer(name: "Grant", displayOrder: 0, scores: [score])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            players: [player]
        )
        let course = try #require(CourseMapPoint(round: round))
        let viewModel = CourseMapViewModel(course: course, currentHoleNumber: 13, round: round)

        #expect(viewModel.teeBoxTitle(for: 13) == "Tee Box 13 - Par 3")
        #expect(viewModel.greenTitle(for: 13) == "Green 13 - Par 3")
        #expect(viewModel.teeBoxTitle(for: 14) == "Tee Box 14")
    }

    @Test func courseMapViewModelSaveHoleRequiresShotsOrScoreBeforeAdvancing() throws {
        let firstScore = HoleScore(holeNumber: 1, par: 4)
        let secondScore = HoleScore(holeNumber: 2, par: 5)
        let player = RoundPlayer(name: "Grant", displayOrder: 0, scores: [firstScore, secondScore])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            players: [player]
        )
        let course = try #require(CourseMapPoint(round: round))
        let viewModel = CourseMapViewModel(course: course, round: round)

        #expect(viewModel.canSaveHole == false)
        #expect(viewModel.saveHoleButtonTitle == "Save Hole")
        #expect(viewModel.saveHoleActionAccessibilityLabel == "Save hole and go to next hole")
        viewModel.saveCurrentHole()
        #expect(round.currentHole == 1)

        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))
        #expect(viewModel.canSaveHole)
        viewModel.saveCurrentHole()

        #expect(firstScore.strokes == 1)
        #expect(round.currentHole == 2)
        #expect(viewModel.targetHoleNumber == 2)
        #expect(viewModel.shotMarkers.isEmpty)
    }

    @Test func courseMapViewModelMovingHolesSyncsScoreAndRestoresHoleSession() throws {
        let firstScore = HoleScore(holeNumber: 1, par: 4)
        let secondScore = HoleScore(holeNumber: 2, par: 5)
        let player = RoundPlayer(name: "Grant", displayOrder: 0, scores: [firstScore, secondScore])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            players: [player]
        )
        let course = try #require(CourseMapPoint(round: round))
        let viewModel = CourseMapViewModel(course: course, round: round)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let pin = CLLocationCoordinate2D(latitude: 33.003, longitude: -84.0)
        let measurement = CLLocationCoordinate2D(latitude: 33.0005, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: tee)
        viewModel.selectionMode = .holePin
        viewModel.selectMapLocation(at: pin)
        viewModel.selectionMode = .measurementPin
        viewModel.selectMapLocation(at: measurement)
        viewModel.selectionMode = .shotStart
        viewModel.selectMapLocation(at: tee)
        viewModel.selectionMode = .shotBall
        viewModel.selectMapLocation(at: ball)

        viewModel.moveToNextHole()
        let selectedHoleScore = try #require(viewModel.selectedHoleScore)

        #expect(firstScore.strokes == 1)
        #expect(round.currentHole == 2)
        #expect(viewModel.targetHoleNumber == 2)
        #expect(selectedHoleScore === secondScore)
        #expect(viewModel.shotMarkers.isEmpty)
        #expect(viewModel.teeBoxCoordinate == nil)
        #expect(viewModel.holePinCoordinate == nil)
        #expect(viewModel.measuredCoordinate == nil)

        viewModel.moveToPreviousHole()

        #expect(round.currentHole == 1)
        #expect(viewModel.shotMarkers.count == 1)
        #expect(viewModel.teeBoxCoordinate?.latitude == tee.latitude)
        #expect(viewModel.holePinCoordinate?.latitude == pin.latitude)
        #expect(viewModel.measuredCoordinate?.latitude == measurement.latitude)
    }

    @Test func courseMapViewModelSaveHoleFinishesOnFinalHole() throws {
        let firstScore = HoleScore(holeNumber: 1, par: 4, strokes: 4)
        let secondScore = HoleScore(holeNumber: 2, par: 5, strokes: 5)
        let player = RoundPlayer(name: "Grant", displayOrder: 0, scores: [firstScore, secondScore])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            currentHole: 2,
            players: [player]
        )
        let course = try #require(CourseMapPoint(round: round))
        let viewModel = CourseMapViewModel(course: course, round: round)

        #expect(viewModel.canSaveHole)
        #expect(viewModel.saveHoleButtonTitle == "Save Hole")
        #expect(viewModel.saveHoleActionAccessibilityLabel == "Save final hole and finish round")

        viewModel.saveCurrentHole()

        #expect(round.currentHole == 2)
        #expect(round.completedAt != nil)
    }

    @Test func courseMapViewModelAdjustsCameraZoomRotationAndFocus() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let viewModel = CourseMapViewModel(course: course)
        let initialDistance = viewModel.cameraDistance
        let teeBox = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.001)

        viewModel.zoomIn()
        #expect(viewModel.cameraDistance < initialDistance)

        viewModel.zoomOut()
        #expect(viewModel.cameraDistance == initialDistance)

        viewModel.rotateLeft()
        #expect(viewModel.cameraHeading == 345)

        viewModel.rotateRight()
        #expect(viewModel.cameraHeading == 0)

        viewModel.rotateRight()
        #expect(viewModel.cameraHeading == 15)

        viewModel.resetNorth()
        #expect(viewModel.cameraHeading == 0)

        viewModel.selectionMode = .teeBox
        viewModel.selectMapLocation(at: teeBox)
        viewModel.showTeeBox()

        #expect(viewModel.cameraCenter.latitude == teeBox.latitude)
        #expect(viewModel.cameraCenter.longitude == teeBox.longitude)
    }

    @Test func courseCoordinateEditorPersistsAndClearsManualCoursePin() throws {
        let schema = Schema([GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let course = GolfCourse(externalID: 271, clubName: "Example Club", courseName: "Example Course")
        let editor = CourseCoordinateEditor()

        modelContext.insert(course)
        try modelContext.save()
        try editor.save(latitudeText: "33.750100", longitudeText: "-84.390200", for: course, modelContext: modelContext)

        var courses = try modelContext.fetch(FetchDescriptor<GolfCourse>())
        var fetchedCourse = try #require(courses.first)

        #expect(fetchedCourse.latitude == 33.750100)
        #expect(fetchedCourse.longitude == -84.390200)

        try editor.clearCoordinates(for: fetchedCourse, modelContext: modelContext)

        courses = try modelContext.fetch(FetchDescriptor<GolfCourse>())
        fetchedCourse = try #require(courses.first)

        #expect(fetchedCourse.latitude == nil)
        #expect(fetchedCourse.longitude == nil)
    }

    @Test func courseCoordinateEditorRejectsInvalidManualCoursePin() {
        let editor = CourseCoordinateEditor()

        #expect(throws: CourseCoordinateEditorError.invalidLatitude) {
            try editor.coordinate(latitudeText: "120", longitudeText: "-84.39")
        }

        #expect(throws: CourseCoordinateEditorError.invalidLongitude) {
            try editor.coordinate(latitudeText: "33.75", longitudeText: "-220")
        }
    }

    @Test func courseGeometryEditorPersistsUserMappedFeaturePoint() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let editor = CourseGeometryEditor()

        _ = try editor.addFeaturePoint(
            courseExternalID: 314,
            holeNumber: 7,
            kind: .layup,
            label: "Creek layup",
            coordinate: CLLocationCoordinate2D(latitude: 33.7504, longitude: -84.3904),
            modelContext: modelContext
        )

        let geometries = try modelContext.fetch(FetchDescriptor<CourseGeometry>())
        let geometry = try #require(geometries.first)
        let hole = try #require(geometry.holes.first)
        let featurePoint = try #require(hole.featurePoints.first)

        #expect(geometries.count == 1)
        #expect(geometry.courseExternalID == 314)
        #expect(geometry.sourceRawValue == CourseGeometrySource.userMapped.rawValue)
        #expect(hole.number == 7)
        #expect(featurePoint.kind == .layup)
        #expect(featurePoint.source == .userMapped)
        #expect(featurePoint.label == "Creek layup")
        #expect(featurePoint.latitude == 33.7504)
        #expect(featurePoint.longitude == -84.3904)
    }

    @Test func courseGeometryEditorDeletesOnlyUserMappedFeaturePoints() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let editor = CourseGeometryEditor()
        let userTarget = CourseMapFeaturePoint(kind: .hazard, label: "User bunker", latitude: 33.7504, longitude: -84.3904)
        let osmTarget = CourseMapFeaturePoint(
            kind: .hazard,
            label: "OSM bunker",
            latitude: 33.7505,
            longitude: -84.3905,
            source: .openStreetMap
        )
        let geometry = CourseGeometry(
            courseExternalID: 314,
            source: .openStreetMap,
            sourceName: "OpenStreetMap",
            holes: [
                HoleGeometry(number: 7, featurePoints: [userTarget, osmTarget])
            ]
        )

        modelContext.insert(geometry)
        try modelContext.save()
        try editor.deleteUserMappedFeaturePoint(userTarget, modelContext: modelContext)

        let restoredGeometry = try #require(try modelContext.fetch(FetchDescriptor<CourseGeometry>()).first)
        let restoredHole = try #require(restoredGeometry.holes.first { $0.number == 7 })

        #expect(restoredHole.featurePoints.contains { $0.label == "User bunker" } == false)
        #expect(restoredHole.featurePoints.contains { $0.label == "OSM bunker" })
    }

    @Test func openStreetMapNormalizerMapsGolfTagsToGeometryImport() throws {
        let json = """
        {
          "elements": [
            {
              "type": "way",
              "id": 100,
              "tags": { "golf": "hole", "ref": "1" },
              "geometry": [
                { "lat": 33.0000, "lon": -84.0000 },
                { "lat": 33.0200, "lon": -84.0000 }
              ]
            },
            {
              "type": "way",
              "id": 101,
              "tags": { "golf": "green", "ref": "1" },
              "geometry": [
                { "lat": 33.0190, "lon": -84.0010 },
                { "lat": 33.0210, "lon": -84.0010 },
                { "lat": 33.0210, "lon": -83.9990 },
                { "lat": 33.0190, "lon": -83.9990 }
              ]
            },
            {
              "type": "way",
              "id": 102,
              "tags": { "golf": "tee", "ref": "1", "name": "Blue Tee" },
              "geometry": [
                { "lat": 33.0000, "lon": -84.0002 },
                { "lat": 33.0002, "lon": -84.0002 }
              ]
            },
            {
              "type": "node",
              "id": 103,
              "lat": 33.0100,
              "lon": -84.0003,
              "tags": { "golf": "bunker", "name": "Right bunker" }
            }
          ]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenStreetMapOverpassResponse.self, from: json)
        let geometryImport = OpenStreetMapGolfGeometryNormalizer().normalizedImport(courseExternalID: 42, elements: response.elements)
        let hole = try #require(geometryImport.holes.first)
        let teePoint = try #require(hole.featurePoints.first { $0.kind == .teeBox && $0.label == "Blue Tee" })
        let hazardPoint = try #require(hole.featurePoints.first { $0.kind == .hazard })

        #expect(geometryImport.source == .openStreetMap)
        #expect(geometryImport.attribution == "© OpenStreetMap contributors, ODbL")
        #expect(geometryImport.holes.count == 1)
        #expect(hole.number == 1)
        #expect(abs((hole.greenCenterCoordinate?.latitude ?? 0) - 33.0200) < 0.000001)
        #expect(abs((hole.greenCenterCoordinate?.longitude ?? 0) + 84.0000) < 0.000001)
        #expect(hole.greenFrontCoordinate != nil)
        #expect(hole.greenBackCoordinate != nil)
        #expect(abs(teePoint.coordinate.latitude - 33.0001) < 0.000001)
        #expect(hazardPoint.label == "Right bunker")
    }

    @Test func courseGeometryEditorImportsOpenStreetMapWithoutOverwritingUserAnchors() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let editor = CourseGeometryEditor()
        let userTee = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0001)
        let userPin = CLLocationCoordinate2D(latitude: 33.0011, longitude: -84.0001)
        let osmTee = CLLocationCoordinate2D(latitude: 33.0003, longitude: -84.0003)
        let osmGreen = CLLocationCoordinate2D(latitude: 33.0013, longitude: -84.0003)

        _ = try editor.setStickyHoleAnchor(
            courseExternalID: 42,
            holeNumber: 1,
            kind: .teeBox,
            coordinate: userTee,
            modelContext: modelContext
        )
        _ = try editor.setStickyHoleAnchor(
            courseExternalID: 42,
            holeNumber: 1,
            kind: .greenPin,
            coordinate: userPin,
            modelContext: modelContext
        )

        _ = try editor.importGeometry(
            CourseGeometryImport(
                courseExternalID: 42,
                source: .openStreetMap,
                sourceName: "OpenStreetMap",
                attribution: "© OpenStreetMap contributors, ODbL",
                holes: [
                    HoleGeometryImport(
                        number: 1,
                        greenCenterCoordinate: osmGreen,
                        featurePoints: [
                            CourseGeometryFeatureImport(kind: .teeBox, label: "OSM Tee 1", coordinate: osmTee, sortOrder: 0)
                        ]
                    )
                ]
            ),
            modelContext: modelContext
        )

        let geometries = try modelContext.fetch(FetchDescriptor<CourseGeometry>())
        let geometry = try #require(geometries.first)
        let hole = try #require(geometry.holes.first { $0.number == 1 })
        let viewModel = CourseMapViewModel(
            course: CourseMapPoint(id: 42, courseName: "Example Course", clubName: "Example Club", latitude: 33.0, longitude: -84.0),
            currentHoleNumber: 1
        )

        viewModel.applyStoredHoleSetup(from: geometries)

        #expect(geometry.sourceRawValue == CourseGeometrySource.openStreetMap.rawValue)
        #expect(geometry.attribution == "© OpenStreetMap contributors, ODbL")
        #expect(hole.featurePoints.contains { $0.kind == .teeBox && $0.source == .userMapped })
        #expect(hole.featurePoints.contains { $0.kind == .teeBox && $0.source == .openStreetMap })
        #expect(hole.featurePoints.contains { $0.kind == .greenPin && $0.source == .userMapped })
        #expect(hole.greenCenterLatitude == osmGreen.latitude)
        #expect(viewModel.teeBoxCoordinate?.latitude == userTee.latitude)
        #expect(viewModel.holePinCoordinate?.latitude == userPin.latitude)
    }

    @Test func courseGeometryStrategyReportsMissingAndAvailableGeometry() {
        let strategy = CourseGeometryStrategy()
        let missingReport = strategy.report(for: nil)
        let geometry = CourseGeometry(
            courseExternalID: 42,
            source: .licensedProvider,
            sourceName: "Licensed Geometry Feed",
            holes: [
                HoleGeometry(
                    number: 1,
                    greenFrontLatitude: 33.7501,
                    greenFrontLongitude: -84.3901,
                    greenCenterLatitude: 33.7502,
                    greenCenterLongitude: -84.3902,
                    greenBackLatitude: 33.7503,
                    greenBackLongitude: -84.3903,
                    greenContourAssetIdentifier: "green-1",
                    flyoverAssetIdentifier: "flyover-1",
                    featurePoints: [
                        CourseMapFeaturePoint(kind: .hazard, label: "Front bunker", latitude: 33.7504, longitude: -84.3904),
                        CourseMapFeaturePoint(kind: .target, label: "Layup", latitude: 33.7505, longitude: -84.3905)
                    ]
                )
            ]
        )
        let report = strategy.report(for: geometry)

        #expect(strategy.selectedSource == .openStreetMap)
        #expect(missingReport.greenYardages == .missingGeometry)
        #expect(missingReport.hasOnCourseGeometry == false)
        #expect(report.sourceName == "Licensed Geometry Feed")
        #expect(report.greenYardages == .available)
        #expect(report.hazards == .available)
        #expect(report.targets == .available)
        #expect(report.greenContours == .available)
        #expect(report.flyovers == .available)
        #expect(report.hasOnCourseGeometry)
    }

    @Test func golfCourseAPIDecoderHandlesFlexibleNumericValues() throws {
        let json = """
        {
          "courses": [
            {
              "id": "42",
              "club_name": "Example Club",
              "course_name": "Example Course",
              "location": {
                "address": "1 Fairway",
                "city": "Atlanta",
                "state": "GA",
                "country": "USA",
                "latitude": "33.75",
                "longitude": -84.39
              },
              "tees": {
                "male": [
                  {
                    "tee_name": "Blue",
                    "course_rating": "71.2",
                    "slope_rating": "130",
                    "total_yards": "6800",
                    "par_total": "72",
                    "holes": [
                      { "par": "4", "yardage": "410", "handicap": "7" }
                    ]
                  }
                ],
                "female": []
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GolfCourseAPISearchResponse.self, from: json)
        let course = try #require(response.courses.first)
        let tee = try #require(course.allTees.first)
        let hole = try #require(tee.holesWithNumbers.first)

        #expect(course.id == 42)
        #expect(course.displayName == "Example Club - Example Course")
        #expect(course.location.latitude == 33.75)
        #expect(course.location.longitude == -84.39)
        #expect(tee.gender == "male")
        #expect(tee.courseRating == 71.2)
        #expect(tee.slopeRating == 130)
        #expect(hole.number == 1)
        #expect(hole.yardage == 410)
    }

    @Test func courseSearchViewModelTracksSelectedTee() throws {
        let json = """
        {
          "courses": [
            {
              "id": 42,
              "club_name": "Example Club",
              "course_name": "Example Course",
              "location": {},
              "tees": {
                "male": [
                  {
                    "tee_name": "Blue",
                    "total_yards": 6800,
                    "par_total": 72,
                    "holes": []
                  },
                  {
                    "tee_name": "White",
                    "total_yards": 6200,
                    "par_total": 72,
                    "holes": []
                  }
                ],
                "female": []
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GolfCourseAPISearchResponse.self, from: json)
        let course = try #require(response.courses.first)
        let whiteTee = try #require(course.allTees.first { $0.teeName == "White" })
        let viewModel = CourseSearchViewModel(apiKey: "test-key")

        viewModel.selectTee(id: whiteTee.id)

        #expect(viewModel.selectedTeeID == whiteTee.id)
    }

    @Test func courseRecentsStorePersistsEncodedSummaries() throws {
        let suiteName = "BigForeTests.CourseRecents.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsCourseRecentsStore(userDefaults: userDefaults, key: "recents")
        let recents = [
            CourseRecent(id: 42, displayName: "Example Club - Example Course", locationText: "1 Fairway"),
            CourseRecent(id: 43, displayName: "Other Club", locationText: "Atlanta, GA")
        ]

        store.save(recents)

        let restoredRecents = UserDefaultsCourseRecentsStore(userDefaults: userDefaults, key: "recents").load()

        #expect(restoredRecents == recents)
    }

    @Test func courseSearchViewModelMovesDuplicateRecentToFront() throws {
        let store = InMemoryCourseRecentsStore(initialRecents: [
            CourseRecent(id: 1, displayName: "First Club"),
            CourseRecent(id: 2, displayName: "Old Second Club"),
            CourseRecent(id: 3, displayName: "Third Club")
        ])
        let viewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in StubGolfCourseAPIClient() },
            recentsStore: store
        )
        let updatedCourse = try makeAPICourse(
            id: 2,
            clubName: "Updated Club",
            courseName: "Updated Course",
            address: "2 Fairway"
        )

        viewModel.recordRecent(course: updatedCourse)

        #expect(viewModel.recents.map(\.id) == [2, 1, 3])
        #expect(viewModel.recents.first?.displayName == "Updated Club - Updated Course")
        #expect(viewModel.recents.first?.locationText == "2 Fairway")
        #expect(store.savedRecents == viewModel.recents)
    }

    @Test func courseSearchViewModelCapsRecentsAtTwenty() throws {
        let initialRecents = (1...20).map { id in
            CourseRecent(id: id, displayName: "Course \(id)")
        }
        let store = InMemoryCourseRecentsStore(initialRecents: initialRecents)
        let viewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in StubGolfCourseAPIClient() },
            recentsStore: store
        )
        let newCourse = try makeAPICourse(id: 21, clubName: "Newest Club", courseName: "Newest Course")

        viewModel.recordRecent(course: newCourse)

        #expect(viewModel.recents.count == 20)
        #expect(viewModel.recents.first?.id == 21)
        #expect(viewModel.recents.map(\.id).contains(20) == false)
        #expect(store.savedRecents.count == 20)
    }

    @Test func courseSearchViewModelReportsSearchQueryPresence() {
        let viewModel = CourseSearchViewModel(apiKey: "test-key")

        #expect(viewModel.hasSearchQuery == false)

        viewModel.query = "  Golden Horseshoe  "

        #expect(viewModel.hasSearchQuery)
    }

    @Test func courseSearchViewModelDeletesAndClearsRecents() {
        let store = InMemoryCourseRecentsStore(initialRecents: [
            CourseRecent(id: 1, displayName: "First Club"),
            CourseRecent(id: 2, displayName: "Second Club"),
            CourseRecent(id: 3, displayName: "Third Club")
        ])
        let viewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in StubGolfCourseAPIClient() },
            recentsStore: store
        )

        viewModel.deleteRecent(id: 2)

        #expect(viewModel.recents.map(\.id) == [1, 3])
        #expect(store.savedRecents == viewModel.recents)

        viewModel.clearRecents()

        #expect(viewModel.recents.isEmpty)
        #expect(store.savedRecents.isEmpty)
    }

    @Test func courseSearchViewModelRecordsRecentAfterLoadingCourse() async throws {
        let course = try makeAPICourse(
            id: 42,
            clubName: "Example Club",
            courseName: "Example Course",
            address: "1 Fairway"
        )
        let apiClient = StubGolfCourseAPIClient(coursesByID: [42: course])
        let store = InMemoryCourseRecentsStore()
        let viewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in apiClient },
            recentsStore: store
        )

        await viewModel.loadCourse(id: 42)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.selectedCourse?.id == 42)
        #expect(viewModel.recents == [CourseRecent(course: course)])
        #expect(store.savedRecents == viewModel.recents)
    }

    @Test func courseSearchViewModelLoadsOpenStreetMapGeometryWhenMissing() async throws {
        let apiCourse = try makeAPICourse(
            id: 42,
            clubName: "Example Club",
            courseName: "Example Course",
            latitude: 33.75,
            longitude: -84.39
        )
        let apiClient = StubGolfCourseAPIClient(coursesByID: [42: apiCourse])
        let geometryProvider = StubOpenStreetMapGolfGeometryProvider()
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let viewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in apiClient },
            geometryProvider: geometryProvider
        )

        await viewModel.loadCourse(id: 42)
        await viewModel.ensureOpenStreetMapGeometryIfNeeded(modelContext: modelContext)

        let geometries = try modelContext.fetch(FetchDescriptor<CourseGeometry>())
        let geometry = try #require(geometries.first)

        #expect(geometryProvider.requestCount == 1)
        #expect(geometry.courseExternalID == 42)
        #expect(geometry.sourceRawValue == CourseGeometrySource.openStreetMap.rawValue)
        #expect(viewModel.statusMessage == "Loaded OpenStreetMap geometry for 1 hole.")
    }

    @Test func courseSearchViewModelSkipsOpenStreetMapGeometryWhenCached() async throws {
        let apiCourse = try makeAPICourse(
            id: 42,
            clubName: "Example Club",
            courseName: "Example Course",
            latitude: 33.75,
            longitude: -84.39
        )
        let apiClient = StubGolfCourseAPIClient(coursesByID: [42: apiCourse])
        let geometryProvider = StubOpenStreetMapGolfGeometryProvider()
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let cachedGeometry = CourseGeometry(
            courseExternalID: 42,
            source: .openStreetMap,
            sourceName: "OpenStreetMap",
            holes: [HoleGeometry(number: 1, greenCenterLatitude: 33.75, greenCenterLongitude: -84.39)]
        )
        let viewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in apiClient },
            geometryProvider: geometryProvider
        )

        modelContext.insert(cachedGeometry)
        try modelContext.save()
        await viewModel.loadCourse(id: 42)
        await viewModel.ensureOpenStreetMapGeometryIfNeeded(modelContext: modelContext)

        #expect(geometryProvider.requestCount == 0)
    }

    @Test func saveCoursePersistsTeesAndHoles() throws {
        let json = """
        {
          "courses": [
            {
              "id": 314,
              "club_name": "Example Club",
              "course_name": "Example Course",
              "location": {
                "address": "1 Fairway",
                "city": "Atlanta",
                "state": "GA",
                "country": "USA"
              },
              "tees": {
                "male": [
                  {
                    "tee_name": "Blue",
                    "course_rating": 71.2,
                    "slope_rating": 130,
                    "total_yards": 6800,
                    "par_total": 72,
                    "holes": [
                      { "par": 4, "yardage": 410, "handicap": 7 },
                      { "par": 5, "yardage": 520, "handicap": 3 }
                    ]
                  }
                ],
                "female": []
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GolfCourseAPISearchResponse.self, from: json)
        let apiCourse = try #require(response.courses.first)
        let schema = Schema([GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let viewModel = CourseSearchViewModel(apiKey: "test-key")

        viewModel.save(course: apiCourse, modelContext: modelContext)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.statusMessage == "Saved Example Club - Example Course.")

        let courses = try modelContext.fetch(FetchDescriptor<GolfCourse>())
        let savedCourse = try #require(courses.first)
        let savedTee = try #require(savedCourse.tees.first)
        let savedHole = try #require(savedTee.holes.sorted { $0.number < $1.number }.first)

        #expect(courses.count == 1)
        #expect(savedCourse.externalID == 314)
        #expect(savedCourse.tees.count == 1)
        #expect(savedTee.course === savedCourse)
        #expect(savedTee.holes.count == 2)
        #expect(savedHole.tee === savedTee)
        #expect(savedHole.number == 1)
        #expect(savedHole.par == 4)
    }

    @Test func courseGeometryPersistsHoleGeometryAndFeaturePoints() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let geometry = CourseGeometry(
            courseExternalID: 314,
            source: .licensedProvider,
            sourceName: "Licensed Geometry Feed",
            attribution: "Example attribution",
            holes: [
                HoleGeometry(
                    number: 1,
                    greenFrontLatitude: 33.7501,
                    greenFrontLongitude: -84.3901,
                    greenCenterLatitude: 33.7502,
                    greenCenterLongitude: -84.3902,
                    greenBackLatitude: 33.7503,
                    greenBackLongitude: -84.3903,
                    featurePoints: [
                        CourseMapFeaturePoint(kind: .hazard, label: "Creek", latitude: 33.7504, longitude: -84.3904)
                    ]
                )
            ]
        )

        modelContext.insert(geometry)
        try modelContext.save()

        let geometries = try modelContext.fetch(FetchDescriptor<CourseGeometry>())
        let fetchedGeometry = try #require(geometries.first)
        let fetchedHole = try #require(fetchedGeometry.holes.first)
        let featurePoint = try #require(fetchedHole.featurePoints.first)

        #expect(geometries.count == 1)
        #expect(fetchedGeometry.courseExternalID == 314)
        #expect(fetchedGeometry.sourceRawValue == CourseGeometrySource.licensedProvider.rawValue)
        #expect(fetchedGeometry.attribution == "Example attribution")
        #expect(fetchedHole.courseGeometry === fetchedGeometry)
        #expect(fetchedHole.number == 1)
        #expect(featurePoint.holeGeometry === fetchedHole)
        #expect(featurePoint.kindRawValue == CourseMapFeatureKind.hazard.rawValue)
        #expect(featurePoint.label == "Creek")
    }

    @Test func roundBuilderTrimsPlayersCapsAtEightAndCopiesCourseCoordinates() {
        let course = RoundSetupCourse(
            externalID: 42,
            clubName: "Example Club",
            courseName: "Example Course",
            latitude: 33.75,
            longitude: -84.39
        )
        let tee = RoundSetupTee(
            gender: "male",
            name: "Blue",
            totalYards: 6800,
            parTotal: 72,
            holes: [
                RoundSetupHole(number: 1, par: nil, yardage: 410, handicap: 7),
                RoundSetupHole(number: 2, par: 5, yardage: 520, handicap: 3)
            ]
        )

        let round = RoundBuilder().makeRound(
            course: course,
            tee: tee,
            scoringMode: .strokePlay,
            playerNames: [" Grant ", "", "Alex", "Sam", "Jo", "Lee", "Kai", "Ari", "Bea", "Cam"]
        )
        let players = round.players.sorted { $0.displayOrder < $1.displayOrder }
        let firstScores = players[0].scores.sorted { $0.holeNumber < $1.holeNumber }

        #expect(round.courseExternalID == 42)
        #expect(round.courseLatitude == 33.75)
        #expect(round.courseLongitude == -84.39)
        #expect(round.teeName == "Blue")
        #expect(players.map(\.name) == ["Grant", "Alex", "Sam", "Jo", "Lee", "Kai", "Ari", "Bea"])
        #expect(firstScores.map(\.holeNumber) == [1, 2])
        #expect(firstScores[0].par == 4)
        #expect(firstScores[1].par == 5)
    }

    @Test func roundPersistenceSavesFetchesPlayersScoresAndInverses() throws {
        let course = RoundSetupCourse(
            externalID: 42,
            clubName: "Example Club",
            courseName: "Example Course",
            latitude: 33.75,
            longitude: -84.39
        )
        let tee = RoundSetupTee(
            gender: "male",
            name: "Blue",
            totalYards: 6800,
            parTotal: 72,
            holes: [
                RoundSetupHole(number: 1, par: 4, yardage: 410, handicap: 7),
                RoundSetupHole(number: 2, par: 5, yardage: 520, handicap: 3)
            ]
        )
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let round = RoundBuilder().makeRound(
            course: course,
            tee: tee,
            scoringMode: .stableford,
            playerNames: ["Grant", "Alex"]
        )

        modelContext.insert(round)
        try modelContext.save()

        let rounds = try modelContext.fetch(FetchDescriptor<GolfRound>())
        let players = try modelContext.fetch(FetchDescriptor<RoundPlayer>())
        let scores = try modelContext.fetch(FetchDescriptor<HoleScore>())
        let fetchedRound = try #require(rounds.first)
        let fetchedPlayers = fetchedRound.players.sorted { $0.displayOrder < $1.displayOrder }
        let firstPlayer = try #require(fetchedPlayers.first)
        let firstPlayerScores = firstPlayer.scores.sorted { $0.holeNumber < $1.holeNumber }
        let firstScore = try #require(firstPlayerScores.first)

        #expect(rounds.count == 1)
        #expect(players.count == 2)
        #expect(scores.count == 4)
        #expect(fetchedRound.scoringMode == .stableford)
        #expect(fetchedPlayers.map(\.name) == ["Grant", "Alex"])
        #expect(firstPlayer.round === fetchedRound)
        #expect(firstPlayerScores.map(\.holeNumber) == [1, 2])
        #expect(firstScore.player === firstPlayer)
        #expect(firstScore.yardage == 410)
        #expect(firstScore.handicap == 7)
    }

    @Test func scorecardViewModelBuildsFrontBackAndRoundSummaries() {
        let scores = (1...18).map { holeNumber in
            HoleScore(holeNumber: holeNumber, par: holeNumber <= 9 ? 4 : 5, yardage: holeNumber <= 9 ? 400 : 500)
        }
        let player = RoundPlayer(name: "Grant", displayOrder: 0, scores: scores)
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            players: [player]
        )
        let viewModel = ScorecardViewModel(round: round)

        #expect(viewModel.frontNineHoles == Array(1...9))
        #expect(viewModel.backNineHoles == Array(10...18))
        #expect(viewModel.frontNineSummaryText == "Par 36 · 3600 yds")
        #expect(viewModel.backNineSummaryText == "Par 45 · 4500 yds")
        #expect(viewModel.roundSummaryText == "Par 81 · 8100 yds")
    }

    @Test func roundsListViewModelFormatsDatesAndDeletesRound() throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2025
        components.month = 7
        components.day = 7
        let startedAt = try #require(components.date)
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            startedAt: startedAt
        )
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let viewModel = RoundsListViewModel()

        modelContext.insert(round)
        try modelContext.save()

        #expect(viewModel.dateText(for: round) == "Monday July 7, 2025")

        viewModel.delete(round, modelContext: modelContext)

        let rounds = try modelContext.fetch(FetchDescriptor<GolfRound>())
        #expect(rounds.isEmpty)
    }

    @Test func weatherViewModelLoadsWeatherSummaryOnce() async throws {
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male"
        )
        let provider = StubWeatherProvider()
        let viewModel = WeatherViewModel(provider: provider)

        await viewModel.loadWeather(for: round)
        await viewModel.loadWeather(for: round)

        let summary = try #require(viewModel.summary(for: round))
        #expect(summary.symbolName == "sun.max.fill")
        #expect(summary.temperatureText == "72°")
        #expect(provider.requestCount == 1)

        viewModel.removeWeather(for: round.id)

        #expect(viewModel.summary(for: round) == nil)
    }

    @Test func weatherViewModelStoresWeatherErrors() async throws {
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male"
        )
        let provider = StubWeatherProvider(error: StubWeatherProviderError.unavailable)
        let viewModel = WeatherViewModel(provider: provider)

        await viewModel.loadWeather(for: round)

        #expect(viewModel.summary(for: round) == nil)
        #expect(viewModel.errorText(for: round) == "Weather unavailable.")
    }
}

@MainActor
private final class InMemoryCourseRecentsStore: CourseRecentsStoring {
    private var storedRecents: [CourseRecent]
    private(set) var savedRecents: [CourseRecent] = []

    init(initialRecents: [CourseRecent] = []) {
        self.storedRecents = initialRecents
    }

    func load() -> [CourseRecent] {
        storedRecents
    }

    func save(_ recents: [CourseRecent]) {
        storedRecents = recents
        savedRecents = recents
    }
}

@MainActor
private final class StubGolfCourseAPIClient: GolfCourseAPIProviding {
    var searchResults: [GolfCourseAPICourse]
    var coursesByID: [Int: GolfCourseAPICourse]

    init(searchResults: [GolfCourseAPICourse] = [], coursesByID: [Int: GolfCourseAPICourse] = [:]) {
        self.searchResults = searchResults
        self.coursesByID = coursesByID
    }

    func search(query: String) async throws -> [GolfCourseAPICourse] {
        searchResults
    }

    func course(id: Int) async throws -> GolfCourseAPICourse {
        guard let course = coursesByID[id] else {
            throw StubGolfCourseAPIError.missingCourse
        }

        return course
    }
}

private enum StubGolfCourseAPIError: Error {
    case missingCourse
}

@MainActor
private final class StubOpenStreetMapGolfGeometryProvider: OpenStreetMapGolfGeometryProviding {
    private(set) var requestCount = 0

    func geometry(for request: OpenStreetMapGolfGeometryRequest) async throws -> CourseGeometryImport {
        requestCount += 1
        return CourseGeometryImport(
            courseExternalID: request.courseExternalID,
            source: .openStreetMap,
            sourceName: "OpenStreetMap",
            attribution: "© OpenStreetMap contributors, ODbL",
            holes: [
                HoleGeometryImport(
                    number: 1,
                    greenCenterCoordinate: CLLocationCoordinate2D(latitude: 33.75, longitude: -84.39),
                    featurePoints: [
                        CourseGeometryFeatureImport(
                            kind: .teeBox,
                            label: "OSM Tee 1",
                            coordinate: CLLocationCoordinate2D(latitude: 33.74, longitude: -84.39),
                            sortOrder: 0
                        )
                    ]
                )
            ]
        )
    }
}

@MainActor
private final class StubWeatherProvider: WeatherProviding {
    private(set) var requestCount = 0
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func weather(for request: WeatherRequest) async throws -> WeatherSummary {
        requestCount += 1
        if let error {
            throw error
        }
        return WeatherSummary(symbolName: "sun.max.fill", temperatureText: "72°")
    }
}

private enum StubWeatherProviderError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Weather unavailable."
    }
}

@MainActor
private func makeAPICourse(
    id: Int,
    clubName: String,
    courseName: String,
    address: String? = nil,
    city: String? = nil,
    state: String? = nil,
    country: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil
) throws -> GolfCourseAPICourse {
    var location: [String: Any] = [:]
    location["address"] = address
    location["city"] = city
    location["state"] = state
    location["country"] = country
    location["latitude"] = latitude
    location["longitude"] = longitude

    let payload: [String: Any] = [
        "courses": [
            [
                "id": id,
                "club_name": clubName,
                "course_name": courseName,
                "location": location,
                "tees": [
                    "male": [],
                    "female": []
                ]
            ]
        ]
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)
    let response = try JSONDecoder().decode(GolfCourseAPISearchResponse.self, from: data)

    return try #require(response.courses.first)
}
