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
                HoleScore(holeNumber: 1, par: 4, strokes: 4, putts: 2, teeShotAccuracy: .fairway),
                HoleScore(holeNumber: 2, par: 5, strokes: 4, putts: 1, teeShotAccuracy: .left),
                HoleScore(holeNumber: 3, par: 3, strokes: 0)
            ]
        )

        let scoring = RoundScoring()

        #expect(scoring.completedHoles(for: player) == 2)
        #expect(scoring.totalStrokes(for: player) == 8)
        #expect(scoring.scoreRelativeToPar(for: player) == -1)
        #expect(scoring.stablefordPoints(for: player) == 5)
        #expect(scoring.totalPutts(for: player) == 3)
        #expect(scoring.fairwaySummary(for: player).hits == 1)
        #expect(scoring.fairwaySummary(for: player).tracked == 2)
        #expect(scoring.girSummary(for: player).hits == 2)
        #expect(scoring.girSummary(for: player).tracked == 2)
        #expect(scoring.relativeText(-1) == "-1")
        #expect(scoring.relativeText(0) == "E")
        #expect(scoring.relativeText(2) == "+2")
    }

    @Test func scoringAggregatesMappedShotsAcrossRounds() {
        let player = RoundPlayer(name: "Grant", displayOrder: 0, scores: [])
        let roundA = GolfRound(
            courseExternalID: 1,
            courseName: "A",
            clubName: "Club",
            teeName: "Blue",
            teeGender: "M",
            completedAt: .now,
            players: [player]
        )
        player.round = roundA
        let shotA = ShotRecord(
            round: roundA,
            player: player,
            holeNumber: 1,
            shotNumber: 1,
            startCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            endCoordinate: CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001),
            distanceYards: 100
        )
        let roundB = GolfRound(
            courseExternalID: 2,
            courseName: "B",
            clubName: "Club",
            teeName: "Blue",
            teeGender: "M",
            completedAt: .now,
            players: []
        )
        let shotB = ShotRecord(
            round: roundB,
            player: nil,
            holeNumber: 1,
            shotNumber: 1,
            startCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            endCoordinate: CLLocationCoordinate2D(latitude: 0.001, longitude: 0.001),
            distanceYards: 200
        )
        roundA.shotRecords = [shotA]
        roundB.shotRecords = [shotB]

        let scoring = RoundScoring()
        let completed = [roundA, roundB]
        #expect(scoring.mappedShotRecords(in: completed).count == 2)
        #expect(scoring.averageMappedShotDistanceYards(in: completed) == 150)
    }

    @Test func courseMapViewModelMapScoringDefaultsAndGuardsPutts() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let player = RoundPlayer(
            name: "Grant",
            displayOrder: 0,
            scores: [HoleScore(holeNumber: 1, par: 4, strokes: 0)]
        )
        let secondPlayer = RoundPlayer(
            name: "Alex",
            displayOrder: 1,
            scores: [HoleScore(holeNumber: 1, par: 4, strokes: 0)]
        )
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            teeName: "Blue",
            teeGender: "male",
            players: [player, secondPlayer]
        )
        modelContext.insert(round)
        try modelContext.save()
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course, currentHoleNumber: 1, round: round)

        courseMapViewModel.incrementScore(for: player)

        let score = try #require(player.scores.first)
        #expect(score.strokes == 1)
        #expect(score.putts == 1)
        #expect(!courseMapViewModel.canIncreasePutts(for: player))

        courseMapViewModel.incrementScore(for: player)
        #expect(score.strokes == 2)
        #expect(score.putts == 1)
        #expect(courseMapViewModel.canIncreasePutts(for: player))

        courseMapViewModel.incrementPutts(for: player)
        courseMapViewModel.incrementPutts(for: player)
        #expect(score.putts == 2)

        courseMapViewModel.decrementScore(for: player)
        #expect(score.strokes == 1)
        #expect(score.putts == 1)

        courseMapViewModel.setTeeShotAccuracy(.bunker, for: player)
        #expect(score.teeShotAccuracy == .bunker)

        courseMapViewModel.setScoreRelativeToPar(-1, for: player)
        #expect(score.strokes == 3)
        #expect(score.putts == 1)

        courseMapViewModel.setScoreRelativeToPar(2, for: player)
        #expect(score.strokes == 6)
        #expect(score.putts == 1)

        courseMapViewModel.selectedScoringPlayerID = secondPlayer.id
        courseMapViewModel.deleteScoringPlayer(secondPlayer, modelContext: modelContext)
        #expect(courseMapViewModel.scoringPlayers.map(\.name) == ["Grant"])
        #expect(courseMapViewModel.selectedScoringPlayerID == player.id)

        courseMapViewModel.deleteScoringPlayer(player, modelContext: modelContext)
        #expect(courseMapViewModel.scoringPlayers.map(\.name) == ["Grant"])
        #expect(courseMapViewModel.errorMessage == "A round needs at least one player.")
    }

    @Test func roundBuilderLinksPrimaryProfileToFirstPlayer() {
        let profile = PlayerProfile(displayName: "Grant", isPrimaryUser: true)
        let course = RoundSetupCourse(
            externalID: 1,
            clubName: "Example Club",
            courseName: "Example Course",
            latitude: nil,
            longitude: nil
        )
        let tee = RoundSetupTee(
            gender: "male",
            name: "Blue",
            totalYards: 6_200,
            parTotal: 72,
            holes: [
                RoundSetupHole(number: 1, par: 4, yardage: 410, handicap: 1),
                RoundSetupHole(number: 2, par: 3, yardage: 160, handicap: 17)
            ]
        )

        let round = RoundBuilder().makeRound(
            course: course,
            tee: tee,
            scoringMode: .strokePlay,
            playerNames: ["Grant", "Toehead"],
            primaryPlayerProfile: profile
        )

        #expect(round.players.first?.playerProfile?.id == profile.id)
        #expect(round.players.first?.scores.first?.teeShotAccuracy == nil)
        #expect(round.players.first?.scores.last?.teeShotAccuracy == .notApplicable)
        #expect(round.players.last?.playerProfile == nil)
    }

    @Test func scorecardScoreResultCategorizesRelativeScores() {
        #expect(ScorecardScoreResult(relativeToPar: -4) == .albatross)
        #expect(ScorecardScoreResult(relativeToPar: -3) == .albatross)
        #expect(ScorecardScoreResult(relativeToPar: -2) == .eagle)
        #expect(ScorecardScoreResult(relativeToPar: -1) == .birdie)
        #expect(ScorecardScoreResult(relativeToPar: 0) == .par)
        #expect(ScorecardScoreResult(relativeToPar: 1) == .bogey)
        #expect(ScorecardScoreResult(relativeToPar: 2) == .doubleBogey)
        #expect(ScorecardScoreResult(relativeToPar: 3) == .triple)
        #expect(ScorecardScoreResult(relativeToPar: 4) == nil)
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

    @Test func playHomeViewModelFormatsDistancePlayerScoresAndGPSAccuracy() {
        let locationService = LocationService()
        let playHomeViewModel = PlayHomeViewModel(locationService: locationService)
        let gp = RoundPlayer(
            name: "Gp.",
            displayOrder: 0,
            scores: [
                HoleScore(holeNumber: 1, par: 4, strokes: 5),
                HoleScore(holeNumber: 2, par: 4, strokes: 4),
                HoleScore(holeNumber: 3, par: 3, strokes: 3)
            ]
        )
        let toehead = RoundPlayer(
            name: "Toehead",
            displayOrder: 1,
            scores: [
                HoleScore(holeNumber: 1, par: 4, strokes: 5),
                HoleScore(holeNumber: 2, par: 4, strokes: 5),
                HoleScore(holeNumber: 3, par: 3, strokes: 4)
            ]
        )
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Riverfront Golf Club",
            clubName: "Riverfront Golf Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "White",
            teeGender: "male",
            currentHole: 4,
            players: [toehead, gp]
        )

        locationService.currentLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 33.1, longitude: -84.0),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: .now
        )

        let scoreSummaries = playHomeViewModel.playerScoreSummaries(for: round)
        #expect(scoreSummaries.map(\.name) == ["Gp.", "Toehead"])
        #expect(scoreSummaries.map(\.score) == ["+1", "+3"])
        #expect(scoreSummaries.map(\.completedHoles) == [3, 3])
        #expect(playHomeViewModel.leaderSummary(for: round) == "Current Leader: Gp. +1")
        #expect(playHomeViewModel.distanceText(for: round).hasPrefix("Distance: "))
        #expect(playHomeViewModel.distanceText(for: round).hasSuffix(" miles"))
        #expect(playHomeViewModel.gpsTitleText(for: round) == "GPS +/- 5 yds")
        #expect(playHomeViewModel.gpsDetailText(for: round) == "+/- 5 yds")
        #expect(playHomeViewModel.isGPSReady(for: round))
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
        let courseMapViewModel = CourseMapViewModel(course: course, locationService: locationService)

        locationService.currentLocation = CLLocation(latitude: 33.0, longitude: -84.0)
        courseMapViewModel.startShotFromCurrentLocation()

        #expect(courseMapViewModel.isTrackingShot)
        #expect(courseMapViewModel.shotEndCoordinate == nil)

        locationService.currentLocation = CLLocation(latitude: 33.001, longitude: -84.0)
        let liveDistance = try #require(courseMapViewModel.shotDistanceText)

        #expect(liveDistance.hasSuffix(" yds"))

        courseMapViewModel.markShotEndAtCurrentLocation()

        #expect(courseMapViewModel.isTrackingShot == false)
        #expect(courseMapViewModel.shotEndCoordinate != nil)
        #expect(courseMapViewModel.shotDistanceText == liveDistance)

        courseMapViewModel.clearShotMeasurement()

        #expect(courseMapViewModel.shotStartCoordinate == nil)
        #expect(courseMapViewModel.shotEndCoordinate == nil)
        #expect(courseMapViewModel.shotDistanceText == nil)
    }

    @Test func courseMapViewModelTracksShotDistanceBetweenTappedPoints() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)

        courseMapViewModel.measurePoint(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.startShotFromMeasuredPoint()
        courseMapViewModel.measurePoint(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))
        courseMapViewModel.markShotEndAtMeasuredPoint()

        let shotDistance = try #require(courseMapViewModel.shotDistanceText)

        #expect(courseMapViewModel.isTrackingShot == false)
        #expect(courseMapViewModel.shotStartCoordinate != nil)
        #expect(courseMapViewModel.shotEndCoordinate != nil)
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
        let courseMapViewModel = CourseMapViewModel(course: course)
        let measurement = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0001)
        let teeBox = CLLocationCoordinate2D(latitude: 33.0002, longitude: -84.0002)
        let holePin = CLLocationCoordinate2D(latitude: 33.0012, longitude: -84.0002)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0003, longitude: -84.0003)
        let ball = CLLocationCoordinate2D(latitude: 33.0008, longitude: -84.0003)

        courseMapViewModel.selectionMode = .measurementPin
        courseMapViewModel.selectMapLocation(at: measurement)
        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: teeBox)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: holePin)
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: shotStart)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)

        #expect(courseMapViewModel.measuredCoordinate?.latitude == measurement.latitude)
        #expect(courseMapViewModel.teeBoxCoordinate?.latitude == teeBox.latitude)
        #expect(courseMapViewModel.holePinCoordinate?.latitude == holePin.latitude)
        #expect(courseMapViewModel.shotStartCoordinate?.latitude == shotStart.latitude)
        #expect(courseMapViewModel.shotEndCoordinate?.latitude == ball.latitude)
        #expect(courseMapViewModel.isTrackingShot == false)
        #expect(courseMapViewModel.selectionMode == .inactive)
    }

    @Test func courseMapViewModelUndoesPlacedMapPinsInReverseOrder() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let measurement = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0001)
        let teeBox = CLLocationCoordinate2D(latitude: 33.0002, longitude: -84.0002)
        let holePin = CLLocationCoordinate2D(latitude: 33.0012, longitude: -84.0002)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0003, longitude: -84.0003)
        let ball = CLLocationCoordinate2D(latitude: 33.0008, longitude: -84.0003)

        courseMapViewModel.selectionMode = .measurementPin
        courseMapViewModel.selectMapLocation(at: measurement)
        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: teeBox)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: holePin)
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: shotStart)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)

        #expect(courseMapViewModel.canUndoLastPin)

        courseMapViewModel.undoLastPin()
        #expect(courseMapViewModel.shotEndCoordinate == nil)
        #expect(courseMapViewModel.shotMarkers.isEmpty)
        #expect(courseMapViewModel.shotStartCoordinate?.latitude == shotStart.latitude)

        courseMapViewModel.undoLastPin()
        #expect(courseMapViewModel.shotStartCoordinate == nil)
        #expect(courseMapViewModel.holePinCoordinate?.latitude == holePin.latitude)

        courseMapViewModel.undoLastPin()
        #expect(courseMapViewModel.holePinCoordinate == nil)
        #expect(courseMapViewModel.teeBoxCoordinate?.latitude == teeBox.latitude)

        courseMapViewModel.undoLastPin()
        #expect(courseMapViewModel.teeBoxCoordinate == nil)
        #expect(courseMapViewModel.measuredCoordinate?.latitude == measurement.latitude)

        courseMapViewModel.undoLastPin()
        #expect(courseMapViewModel.measuredCoordinate == nil)
        #expect(courseMapViewModel.canUndoLastPin == false)
    }

    @Test func courseMapViewModelTapModesDeactivateAfterPlacement() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let firstTee = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let secondTee = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: firstTee)
        courseMapViewModel.selectMapLocation(at: secondTee)

        #expect(courseMapViewModel.selectionMode == .inactive)
        #expect(courseMapViewModel.teeBoxCoordinate?.latitude == firstTee.latitude)
    }

    @Test func courseMapViewModelActionStripButtonsSetTapModes() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course, currentHoleNumber: 4)

        courseMapViewModel.errorMessage = "Previous error"
        courseMapViewModel.setMeasurementPinTapMode()
        #expect(courseMapViewModel.selectionMode == .measurementPin)
        #expect(courseMapViewModel.statusMessage == "Tap the map to drop a measurement pin.")
        #expect(courseMapViewModel.errorMessage == nil)

        courseMapViewModel.setShotStartTapMode()
        #expect(courseMapViewModel.selectionMode == .shotStart)
        #expect(courseMapViewModel.statusMessage == "Tap the map to set shot start for Hole 4.")
        #expect(courseMapViewModel.errorMessage == nil)

        courseMapViewModel.setShotBallTapMode()
        #expect(courseMapViewModel.selectionMode == .shotBall)
        #expect(courseMapViewModel.statusMessage == "Tap the map to set ball location for Hole 4.")

        courseMapViewModel.setTeeBoxTapMode()
        #expect(courseMapViewModel.selectionMode == .teeBox)
        #expect(courseMapViewModel.statusMessage == "Tap the map to save Tee 4.")

        courseMapViewModel.setHolePinTapMode()
        #expect(courseMapViewModel.selectionMode == .holePin)
        #expect(courseMapViewModel.statusMessage == "Tap the map to save Pin 4.")
    }

    @Test func courseMapViewModelTeePinModesFrameHoleLineWithPinAtTop() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course, currentHoleNumber: 15)
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

        courseMapViewModel.setTeeBoxTapMode(geometries: [geometry])

        #expect(courseMapViewModel.selectionMode == .teeBox)
        #expect(courseMapViewModel.teeBoxCoordinate?.latitude == tee.latitude)
        #expect(courseMapViewModel.holePinCoordinate?.longitude == pin.longitude)
        #expect(abs(courseMapViewModel.cameraCenter.longitude - ((tee.longitude + pin.longitude) / 2)) < 0.000001)
        #expect((85...95).contains(courseMapViewModel.cameraHeading))
        #expect(courseMapViewModel.cameraPitch == 55)

        courseMapViewModel.setHolePinTapMode(geometries: [geometry])

        #expect(courseMapViewModel.selectionMode == .holePin)
        #expect((85...95).contains(courseMapViewModel.cameraHeading))
        #expect(courseMapViewModel.cameraPitch == 55)

        courseMapViewModel.selectHole(15, geometries: [geometry])

        #expect((85...95).contains(courseMapViewModel.cameraHeading))
        #expect(courseMapViewModel.cameraPitch == 55)
    }

    @Test func courseMapViewModelBuildsFaintNextHoleTransitionLineTarget() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course, currentHoleNumber: 9)
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

        courseMapViewModel.applyStoredHoleSetup(from: [geometry])
        let transitionCoordinates = try #require(courseMapViewModel.nextHoleTransitionCoordinates(from: [geometry]))

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
        let courseMapViewModel = CourseMapViewModel(course: course)
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

        courseMapViewModel.selectHole(2, geometries: [geometry])

        #expect(courseMapViewModel.targetHoleNumber == 2)
        #expect(courseMapViewModel.teeBoxCoordinate?.latitude == tee.latitude)
        #expect(courseMapViewModel.holePinCoordinate?.latitude == pin.latitude)
        #expect(courseMapViewModel.cameraCenter.latitude == (tee.latitude + pin.latitude) / 2)
        #expect(courseMapViewModel.cameraCenter.longitude == (tee.longitude + pin.longitude) / 2)
    }

    @Test func courseMapViewModelSelectingHoleFallsBackToPreviousHolePin() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
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

        courseMapViewModel.selectHole(3, geometries: [geometry])

        #expect(courseMapViewModel.targetHoleNumber == 3)
        #expect(courseMapViewModel.teeBoxCoordinate == nil)
        #expect(courseMapViewModel.holePinCoordinate == nil)
        #expect(courseMapViewModel.cameraCenter.latitude == previousPin.latitude)
        #expect(courseMapViewModel.cameraCenter.longitude == previousPin.longitude)
    }

    @Test func courseMapViewModelSelectingHoleSkipsMissingPreviousPin() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
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

        courseMapViewModel.selectHole(3, geometries: [geometry])

        #expect(courseMapViewModel.cameraCenter.latitude == holeOnePin.latitude)
        #expect(courseMapViewModel.cameraCenter.longitude == holeOnePin.longitude)
    }

    @Test func courseMapViewModelSelectingHoleKeepsSelectedHolePinPriority() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
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

        courseMapViewModel.selectHole(3, geometries: [geometry])

        #expect(courseMapViewModel.holePinCoordinate?.latitude == selectedPin.latitude)
        #expect(courseMapViewModel.cameraCenter.latitude == selectedPin.latitude)
        #expect(courseMapViewModel.cameraCenter.longitude == selectedPin.longitude)
    }

    @Test func courseMapViewModelSelectingHoleFallsBackToShotLineThenCourseCenter() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course, currentHoleNumber: 2)
        let shotStart = CLLocationCoordinate2D(latitude: 33.010, longitude: -84.010)
        let ball = CLLocationCoordinate2D(latitude: 33.014, longitude: -84.006)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: shotStart)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)
        courseMapViewModel.moveToHole(1)

        courseMapViewModel.selectHole(2, geometries: [])

        #expect(courseMapViewModel.cameraCenter.latitude == (shotStart.latitude + ball.latitude) / 2)
        #expect(courseMapViewModel.cameraCenter.longitude == (shotStart.longitude + ball.longitude) / 2)

        courseMapViewModel.selectHole(3, geometries: [])

        #expect(courseMapViewModel.cameraCenter.latitude == course.latitude)
        #expect(courseMapViewModel.cameraCenter.longitude == course.longitude)
    }

    @Test func startRoundViewModelDefaultsFirstPlayerToPrimaryProfile() {
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
        let startRoundViewModel = StartRoundViewModel(course: course, tee: tee)

        #expect(startRoundViewModel.playerNames == ["Player"])

        let profile = PlayerProfile(displayName: "Grant", isPrimaryUser: true)
        startRoundViewModel.configurePrimaryPlayer(profile)

        #expect(startRoundViewModel.playerNames == ["Grant"])

        startRoundViewModel.removePlayers(at: IndexSet(integer: 0))

        #expect(startRoundViewModel.playerNames == ["Grant"])

        startRoundViewModel.newPlayerName = "Alex"
        startRoundViewModel.addPlayer()

        #expect(startRoundViewModel.playerNames == ["Grant", "Alex"])
    }

    @Test func courseMapViewModelReportsTeeToHolePinDistance() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))

        let teeDistance = try #require(courseMapViewModel.teeToHolePinDistanceText)

        #expect(teeDistance.hasSuffix(" yds"))
        #expect(courseMapViewModel.teeToHolePinCoordinates?.count == 2)
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
        let courseMapViewModel = CourseMapViewModel(course: course, locationService: locationService)
        let manualStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let manualBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let holePin = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        locationService.currentLocation = CLLocation(latitude: 33.0, longitude: -84.0)
        courseMapViewModel.startShotFromCurrentLocation()
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: manualStart)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: holePin)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: manualBall)

        let shotDistance = try #require(courseMapViewModel.shotDistanceText)
        let ballToPinDistance = try #require(courseMapViewModel.shotLocationToHolePinDistanceText)
        locationService.currentLocation = CLLocation(latitude: 33.004, longitude: -84.0)

        #expect(courseMapViewModel.shotStartCoordinate?.latitude == manualStart.latitude)
        #expect(courseMapViewModel.shotEndCoordinate?.latitude == manualBall.latitude)
        #expect(courseMapViewModel.shotDistanceText == shotDistance)
        #expect(courseMapViewModel.shotLocationToHolePinLabel == "Ball to pin")
        #expect(courseMapViewModel.shotLocationToHolePinDistanceText == ballToPinDistance)
    }

    @Test func courseMapViewModelPersistsStickyTeeAndPinFromMapTaps() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self])
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
        let courseMapViewModel = CourseMapViewModel(course: course, currentHoleNumber: 3)
        let teeBox = CLLocationCoordinate2D(latitude: 33.0002, longitude: -84.0002)
        let providerPin = CLLocationCoordinate2D(latitude: 33.0099, longitude: -84.0099)
        let userPin = CLLocationCoordinate2D(latitude: 33.0012, longitude: -84.0002)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: teeBox, modelContext: modelContext)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: userPin, modelContext: modelContext)

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
        let courseMapViewModel = CourseMapViewModel(course: course)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: shotStart)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)

        #expect(courseMapViewModel.shotMarkers.count == 1)
        #expect(courseMapViewModel.shotMarkers.first?.ballCoordinate.latitude == ball.latitude)

        courseMapViewModel.startNextShotFromBall()

        #expect(courseMapViewModel.shotStartCoordinate?.latitude == ball.latitude)
        #expect(courseMapViewModel.shotEndCoordinate == nil)
        #expect(courseMapViewModel.selectionMode == .shotBall)
    }

    @Test func courseMapViewModelFirstBallDefaultsShotStartToTeeBox() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)

        #expect(courseMapViewModel.shotMarkers.count == 1)
        #expect(courseMapViewModel.shotStartCoordinate?.latitude == tee.latitude)
        #expect(courseMapViewModel.shotEndCoordinate?.latitude == ball.latitude)
        #expect(courseMapViewModel.shotMarkers.first?.startCoordinate.latitude == tee.latitude)
    }

    @Test func courseMapViewModelBallTapUpdatesExistingShotWithSameStart() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let firstBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let correctedBall = CLLocationCoordinate2D(latitude: 33.0015, longitude: -84.0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: firstBall)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: correctedBall)

        #expect(courseMapViewModel.shotMarkers.count == 1)
        #expect(courseMapViewModel.shotMarkers.first?.shotNumber == 1)
        #expect(courseMapViewModel.shotMarkers.first?.ballCoordinate.latitude == correctedBall.latitude)
    }

    @Test func courseMapViewModelBallTapAddsNextShotWhenNoStartOrSelectionExists() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let firstBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let secondBall = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: firstBall)
        courseMapViewModel.clearShotMeasurement()
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: secondBall)

        #expect(courseMapViewModel.shotMarkers.count == 2)
        #expect(courseMapViewModel.shotMarkers.first?.shotNumber == 1)
        #expect(courseMapViewModel.shotMarkers.last?.shotNumber == 2)
        #expect(courseMapViewModel.shotMarkers.last?.startCoordinate.latitude == firstBall.latitude)
        #expect(courseMapViewModel.shotMarkers.last?.ballCoordinate.latitude == secondBall.latitude)
    }

    @Test func courseMapViewModelNextShotBallTapUpdatesExistingSubsequentShot() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let firstBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let secondBall = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)
        let correctedSecondBall = CLLocationCoordinate2D(latitude: 33.0025, longitude: -84.0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: firstBall)
        courseMapViewModel.startNextShotFromBall()
        courseMapViewModel.selectMapLocation(at: secondBall)
        let firstMarker = try #require(courseMapViewModel.shotMarkers.first)
        courseMapViewModel.selectShotMarker(id: firstMarker.id)
        courseMapViewModel.startNextShotFromBall()
        courseMapViewModel.selectMapLocation(at: correctedSecondBall)

        #expect(courseMapViewModel.shotMarkers.count == 2)
        #expect(courseMapViewModel.shotMarkers.last?.shotNumber == 2)
        #expect(courseMapViewModel.shotMarkers.last?.ballCoordinate.latitude == correctedSecondBall.latitude)
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
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let course = try #require(CourseMapPoint(round: round))
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        modelContext.insert(round)
        try modelContext.save()
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0), modelContext: modelContext)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0), modelContext: modelContext)

        let marker = try #require(courseMapViewModel.shotMarkers.first)
        courseMapViewModel.selectShotMarker(id: marker.id)
        courseMapViewModel.deleteSelectedShotMarker(modelContext: modelContext)

        #expect(courseMapViewModel.shotMarkers.isEmpty)
        #expect(courseMapViewModel.selectedShotMarkerID == nil)
        #expect(score.strokes == 0)
        #expect(courseMapViewModel.statusMessage == "Deleted shot.")
    }

    @Test func courseGeometryEditorDeletesUserMappedAnchorsButKeepsImportedFallback() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self])
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
        let courseMapViewModel = CourseMapViewModel(course: course)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        #expect(courseMapViewModel.canStartNextShotFromBall == false)
        courseMapViewModel.startNextShotFromBall()
        #expect(courseMapViewModel.shotStartCoordinate == nil)
        #expect(courseMapViewModel.selectionMode == .inactive)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: shotStart)
        #expect(courseMapViewModel.canStartNextShotFromBall == false)

        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)
        #expect(courseMapViewModel.canStartNextShotFromBall)

        courseMapViewModel.startNextShotFromBall()

        #expect(courseMapViewModel.canStartNextShotFromBall == false)
        #expect(courseMapViewModel.shotStartCoordinate?.latitude == ball.latitude)
        #expect(courseMapViewModel.shotEndCoordinate == nil)
        #expect(courseMapViewModel.selectionMode == .shotBall)
    }

    @Test func courseMapViewModelSelectsShotMarkerAndUpdatesBallLocation() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let movedBall = CLLocationCoordinate2D(latitude: 33.0014, longitude: -84.0)
        let holePin = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: holePin)
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: shotStart)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)

        let marker = try #require(courseMapViewModel.shotMarkers.first)
        courseMapViewModel.selectShotMarker(id: marker.id)

        let distanceToPin = try #require(courseMapViewModel.selectedShotMarkerDistanceToPinText)
        let selectedSummary = try #require(courseMapViewModel.selectedMapInfoSummary)
        #expect(selectedSummary.referenceDistanceLabel == "From tee")
        #expect(selectedSummary.referenceDistanceText?.hasSuffix(" yds") == true)
        #expect(selectedSummary.pinDistanceText == distanceToPin)

        courseMapViewModel.selectionMode = .moveShotBall
        courseMapViewModel.selectMapLocation(at: movedBall)

        #expect(distanceToPin.hasSuffix(" yds"))
        #expect(courseMapViewModel.shotMarkers.first?.ballCoordinate.latitude == movedBall.latitude)
        #expect(courseMapViewModel.shotEndCoordinate?.latitude == movedBall.latitude)
        #expect(courseMapViewModel.selectedShotMarkerDistanceToPinText != distanceToPin)
    }

    @Test func courseMapViewModelBuildsAllShotSummariesFromTeePreviousBallAndPin() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let calculator = DistanceCalculator()
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let firstStart = CLLocationCoordinate2D(latitude: 33.0002, longitude: -84.0)
        let firstBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let secondBall = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)
        let pin = CLLocationCoordinate2D(latitude: 33.003, longitude: -84.0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: pin)
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: firstStart)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: firstBall)
        courseMapViewModel.startNextShotFromBall()
        courseMapViewModel.selectMapLocation(at: secondBall)

        let summaries = courseMapViewModel.shotSummaries
        let firstSummary = try #require(summaries.first)
        let secondSummary = try #require(summaries.last)

        #expect(summaries.count == 2)
        #expect(firstSummary.distanceFromPreviousText == calculator.formattedYards(from: tee, to: firstBall))
        #expect(secondSummary.distanceFromPreviousText == calculator.formattedYards(from: firstBall, to: secondBall))
        #expect(firstSummary.distanceToPinText == calculator.formattedYards(from: firstBall, to: pin))
        #expect(secondSummary.distanceToPinText == calculator.formattedYards(from: secondBall, to: pin))
    }

    @Test func courseMapViewModelSelectingShotPreparesBallMoveWithoutChangingCamera() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let firstStart = CLLocationCoordinate2D(latitude: 33.0001, longitude: -84.0)
        let firstBall = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let secondBall = CLLocationCoordinate2D(latitude: 33.004, longitude: -84.0)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: firstStart)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: firstBall)
        courseMapViewModel.startNextShotFromBall()
        courseMapViewModel.selectMapLocation(at: secondBall)
        let cameraCenter = courseMapViewModel.cameraCenter

        let firstMarker = try #require(courseMapViewModel.shotMarkers.first)
        courseMapViewModel.selectShotMarker(id: firstMarker.id)

        #expect(courseMapViewModel.selectedShotMarkerID == firstMarker.id)
        #expect(courseMapViewModel.shotStartCoordinate?.latitude == firstStart.latitude)
        #expect(courseMapViewModel.shotEndCoordinate?.latitude == firstBall.latitude)
        #expect(courseMapViewModel.selectionMode == .moveShotBall)
        #expect(courseMapViewModel.cameraCenter.latitude == cameraCenter.latitude)
        #expect(courseMapViewModel.cameraCenter.longitude == cameraCenter.longitude)
        #expect(courseMapViewModel.shotSummaries.first?.isSelected == true)
    }

    @Test func courseMapViewModelScoreButtonsUpdateCurrentHoleScore() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
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
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        modelContext.insert(round)
        try modelContext.save()

        courseMapViewModel.incrementSelectedHoleScore(modelContext: modelContext)
        courseMapViewModel.incrementSelectedHoleScore(modelContext: modelContext)

        #expect(score.strokes == 2)
        #expect(courseMapViewModel.compactHoleScoreText == "S2")
        #expect(courseMapViewModel.canDecreaseSelectedHoleScore)

        courseMapViewModel.decrementSelectedHoleScore(modelContext: modelContext)

        #expect(score.strokes == 1)

        for _ in 0..<20 {
            courseMapViewModel.incrementSelectedHoleScore(modelContext: modelContext)
        }

        #expect(score.strokes == 12)
        #expect(courseMapViewModel.canIncreaseSelectedHoleScore == false)
    }

    @Test func courseMapViewModelManualShotsUpdateFirstPlayerHoleScore() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
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
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        modelContext.insert(round)
        try modelContext.save()

        courseMapViewModel.incrementSelectedHoleScore(modelContext: modelContext)
        courseMapViewModel.incrementSelectedHoleScore(modelContext: modelContext)
        courseMapViewModel.incrementSelectedHoleScore(modelContext: modelContext)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0), modelContext: modelContext)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0), modelContext: modelContext)
        courseMapViewModel.startNextShotFromBall()
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0), modelContext: modelContext)

        #expect(courseMapViewModel.selectedScoringPlayer?.name == "Grant")
        #expect(grantScore.strokes == 2)
        #expect(alexScore.strokes == 0)
    }

    @Test func courseMapViewModelUsesFocusedScorecardPlayerForShots() throws {
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
            players: [grant, alex]
        )
        let course = try #require(CourseMapPoint(round: round))
        let courseMapViewModel = CourseMapViewModel(course: course, round: round, focusedPlayerID: alex.id)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))

        #expect(courseMapViewModel.selectedScoringPlayer?.name == "Alex")
        #expect(courseMapViewModel.scoringPlayerDetailText == "Ball: Alex")
        #expect(alexScore.strokes == 1)
        #expect(grantScore.strokes == 0)
    }

    @Test func courseMapViewModelPersistsAndRestoresShotRecords() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let club = GolfClub(template: GolfClubTemplate.defaultBag[8])
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
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)
        let shotStart = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        modelContext.insert(club)
        modelContext.insert(round)
        try modelContext.save()
        courseMapViewModel.selectedClubID = club.id
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: shotStart, modelContext: modelContext)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball, modelContext: modelContext)

        let records = try modelContext.fetch(FetchDescriptor<ShotRecord>())
        let record = try #require(records.first)

        #expect(records.count == 1)
        #expect(record.round === round)
        #expect(record.player === player)
        #expect(record.holeNumber == 1)
        #expect(record.shotNumber == 1)
        #expect(record.source == .manualMap)
        #expect(record.club === club)
        #expect(record.clubNameSnapshot == "9 Iron")
        #expect(score.strokes == 1)

        let restoredViewModel = CourseMapViewModel(course: course, round: round)
        restoredViewModel.applyPersistedShotRecords()

        #expect(restoredViewModel.shotMarkers.count == 1)
        #expect(restoredViewModel.shotMarkers.first?.id == record.id)
        #expect(restoredViewModel.shotMarkers.first?.ballCoordinate.latitude == ball.latitude)
        #expect(restoredViewModel.shotSummaries.first?.clubName == "9 Iron")
    }

    @Test func courseMapViewModelDeletingShotRemovesPersistedRecord() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
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
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        modelContext.insert(round)
        try modelContext.save()
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0), modelContext: modelContext)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0), modelContext: modelContext)

        let marker = try #require(courseMapViewModel.shotMarkers.first)
        courseMapViewModel.selectShotMarker(id: marker.id)
        courseMapViewModel.deleteSelectedShotMarker(modelContext: modelContext)

        #expect(try modelContext.fetch(FetchDescriptor<ShotRecord>()).isEmpty)
        #expect(score.strokes == 0)
    }

    @Test func courseMapViewModelBuildsWoodyRecommendationFromDefaultClubDistance() throws {
        let club = GolfClub(template: GolfClubTemplate.defaultBag[8])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male"
        )
        let weatherSnapshot = RoundWeatherSnapshot(
            round: round,
            latitude: 33.0,
            longitude: -84.0,
            symbolName: "sun.max.fill",
            temperatureFahrenheit: 72,
            windSpeedMilesPerHour: 8
        )
        let course = try #require(CourseMapPoint(round: round))
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        round.weatherSnapshots = [weatherSnapshot]
        courseMapViewModel.selectedClubID = club.id
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))

        let recommendation = try #require(courseMapViewModel.clubRecommendation(from: [club]))

        #expect(recommendation.title == "Woody says 9 Iron")
        #expect(recommendation.detail.contains("default"))
        #expect(recommendation.distanceText.hasSuffix("yds to pin"))
        #expect(recommendation.confidenceText == "Best fit from starter bag")
        #expect(recommendation.weatherText == "72° · wind 8 mph")
    }

    @Test func courseMapViewModelRecommendsBestActiveClubInsteadOfSelectedClub() throws {
        let driver = GolfClub(template: GolfClubTemplate.defaultBag[0])
        let pitchingWedge = GolfClub(template: GolfClubTemplate.defaultBag[9])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male"
        )
        let course = try #require(CourseMapPoint(round: round))
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        courseMapViewModel.selectedClubID = driver.id
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))

        let recommendation = try #require(courseMapViewModel.clubRecommendation(from: [driver, pitchingWedge]))

        #expect(recommendation.title == "Woody says PW")
        #expect(recommendation.detail.contains("Selected shot club: Driver"))
    }

    @Test func courseMapViewModelDoesNotRecommendShortClubWhenReachableClubExists() throws {
        let sevenIron = GolfClub(template: GolfClubTemplate.defaultBag[6])
        let pitchingWedge = GolfClub(template: GolfClubTemplate.defaultBag[9])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male"
        )
        let course = try #require(CourseMapPoint(round: round))
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        courseMapViewModel.selectedClubID = pitchingWedge.id
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.00125, longitude: -84.0))

        let recommendation = try #require(courseMapViewModel.clubRecommendation(from: [sevenIron, pitchingWedge]))

        #expect(recommendation.title == "Woody says 7 Iron")
    }

    @Test func courseMapViewModelSelectsWoodyBestFitClub() throws {
        let driver = GolfClub(template: GolfClubTemplate.defaultBag[0])
        let pitchingWedge = GolfClub(template: GolfClubTemplate.defaultBag[9])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male"
        )
        let course = try #require(CourseMapPoint(round: round))
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        courseMapViewModel.selectedClubID = driver.id
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))
        courseMapViewModel.selectWoodyClub(from: [driver, pitchingWedge])

        #expect(courseMapViewModel.selectedClubID == pitchingWedge.id)
    }

    @Test func courseMapViewModelBuildsWoodyRecommendedClubLandingTarget() throws {
        let driver = GolfClub(template: GolfClubTemplate.defaultBag[0])
        let pitchingWedge = GolfClub(template: GolfClubTemplate.defaultBag[9])
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male"
        )
        let course = try #require(CourseMapPoint(round: round))
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)
        let start = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let pin = CLLocationCoordinate2D(latitude: 33.004, longitude: -84.0)

        courseMapViewModel.selectedClubID = driver.id
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: start)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: pin)

        let landingTarget = try #require(courseMapViewModel.clubLandingTarget(from: [driver]))
        let targetDistance = DistanceCalculator().yards(from: start, to: landingTarget.coordinate)

        #expect(landingTarget.title == "Driver target 245 yds")
        #expect((240...250).contains(targetDistance))
        #expect(landingTarget.lineCoordinates.first?.latitude == start.latitude)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: start)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))

        let shorterTarget = try #require(courseMapViewModel.clubLandingTarget(from: [driver, pitchingWedge]))
        let shorterTargetDistance = DistanceCalculator().yards(from: start, to: shorterTarget.coordinate)

        #expect(shorterTarget.title == "PW target 120 yds")
        #expect((115...125).contains(shorterTargetDistance))

        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0005, longitude: -84.0))

        #expect(courseMapViewModel.clubLandingTarget(from: [driver, pitchingWedge]) == nil)
    }

    @Test func courseMapViewModelBuildsWoodyRecommendationFromSavedClubAverage() throws {
        let club = GolfClub(template: GolfClubTemplate.defaultBag[8])
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
        let firstShot = ShotRecord(
            round: round,
            player: player,
            club: club,
            holeNumber: 1,
            shotNumber: 1,
            startCoordinate: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0),
            endCoordinate: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0),
            distanceYards: 120
        )
        let secondShot = ShotRecord(
            round: round,
            player: player,
            club: club,
            holeNumber: 2,
            shotNumber: 1,
            startCoordinate: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0),
            endCoordinate: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0),
            distanceYards: 124
        )
        let thirdShot = ShotRecord(
            round: round,
            player: player,
            club: club,
            holeNumber: 3,
            shotNumber: 1,
            startCoordinate: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0),
            endCoordinate: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0),
            distanceYards: 122
        )
        let course = try #require(CourseMapPoint(round: round))
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        round.shotRecords = [firstShot, secondShot, thirdShot]
        courseMapViewModel.selectedClubID = club.id
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))

        let recommendation = try #require(courseMapViewModel.clubRecommendation(from: [club]))

        #expect(recommendation.detail.contains("122 yds"))
        #expect(recommendation.detail.contains("3-shot average"))
        #expect(recommendation.confidenceText == "Best fit from your saved shots")
    }

    @Test func courseMapViewModelHandleMapTapRequiresSelectedAction() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let tappedCoordinate = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        courseMapViewModel.handleMapTap(at: tappedCoordinate)

        #expect(courseMapViewModel.measuredCoordinate == nil)
        #expect(courseMapViewModel.statusMessage == "Choose a map action before tapping.")
    }

    @Test func courseMapViewModelDeletingMeasuredPointDisablesMapTapAction() {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)

        courseMapViewModel.handleMapTap(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))
        courseMapViewModel.deleteMeasuredPoint()
        courseMapViewModel.handleMapTap(at: CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0))

        #expect(courseMapViewModel.measuredCoordinate == nil)
        #expect(courseMapViewModel.selectionMode == .inactive)
        #expect(courseMapViewModel.statusMessage == "Choose a map action before tapping.")

        courseMapViewModel.selectionMode = .measurementPin
        courseMapViewModel.handleMapTap(at: CLLocationCoordinate2D(latitude: 33.003, longitude: -84.0))

        #expect(courseMapViewModel.measuredCoordinate?.latitude == 33.003)
    }

    @Test func courseMapViewModelSelectedMapInfoUsesCurrentPlayReference() throws {
        let course = CourseMapPoint(
            id: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            latitude: 33.0,
            longitude: -84.0
        )
        let courseMapViewModel = CourseMapViewModel(course: course)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let pin = CLLocationCoordinate2D(latitude: 33.003, longitude: -84.0)
        let hazard = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.002, longitude: -84.0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: pin)
        courseMapViewModel.selectMapInfo(title: "Bunker 1", coordinate: hazard)

        var summary = try #require(courseMapViewModel.selectedMapInfoSummary)
        #expect(summary.referenceDistanceLabel == "Tee to this")
        #expect(summary.referenceDistanceText?.hasSuffix(" yds") == true)
        #expect(summary.pinDistanceText?.hasSuffix(" yds") == true)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.locationService.currentLocation = CLLocation(latitude: 33.0015, longitude: -84.0)
        courseMapViewModel.selectMapInfo(title: "Bunker 1", coordinate: hazard)

        summary = try #require(courseMapViewModel.selectedMapInfoSummary)
        #expect(summary.referenceDistanceLabel == "GPS to this")

        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)
        courseMapViewModel.selectMapInfo(title: "Bunker 1", coordinate: hazard)

        summary = try #require(courseMapViewModel.selectedMapInfoSummary)
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
        let courseMapViewModel = CourseMapViewModel(course: course, currentHoleNumber: 13, round: round)

        #expect(courseMapViewModel.teeBoxTitle(for: 13) == "Tee Box 13 - Par 3")
        #expect(courseMapViewModel.greenTitle(for: 13) == "Green 13 - Par 3")
        #expect(courseMapViewModel.teeBoxTitle(for: 14) == "Tee Box 14")
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
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        #expect(courseMapViewModel.canSaveHole == false)
        #expect(courseMapViewModel.saveHoleButtonTitle == "Save Grant")
        #expect(courseMapViewModel.saveHoleActionAccessibilityLabel == "Save hole for Grant and go to next hole")
        courseMapViewModel.saveCurrentHole()
        #expect(round.currentHole == 1)

        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0))
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0))
        #expect(courseMapViewModel.canSaveHole)
        #expect(courseMapViewModel.saveHoleButtonTitle == "Save Grant")
        #expect(courseMapViewModel.saveHoleHelpText == "Saves Hole 1 for Grant and moves to Hole 2.")
        #expect(courseMapViewModel.scoringPlayerDetailText == "Ball: Grant")
        courseMapViewModel.saveCurrentHole()

        #expect(firstScore.strokes == 1)
        #expect(round.currentHole == 2)
        #expect(courseMapViewModel.targetHoleNumber == 2)
        #expect(courseMapViewModel.shotMarkers.isEmpty)
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
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)
        let tee = CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0)
        let pin = CLLocationCoordinate2D(latitude: 33.003, longitude: -84.0)
        let measurement = CLLocationCoordinate2D(latitude: 33.0005, longitude: -84.0)
        let ball = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.selectionMode = .holePin
        courseMapViewModel.selectMapLocation(at: pin)
        courseMapViewModel.selectionMode = .measurementPin
        courseMapViewModel.selectMapLocation(at: measurement)
        courseMapViewModel.selectionMode = .shotStart
        courseMapViewModel.selectMapLocation(at: tee)
        courseMapViewModel.selectionMode = .shotBall
        courseMapViewModel.selectMapLocation(at: ball)

        courseMapViewModel.moveToNextHole()
        let selectedHoleScore = try #require(courseMapViewModel.selectedHoleScore)

        #expect(firstScore.strokes == 1)
        #expect(round.currentHole == 2)
        #expect(courseMapViewModel.targetHoleNumber == 2)
        #expect(selectedHoleScore === secondScore)
        #expect(courseMapViewModel.shotMarkers.isEmpty)
        #expect(courseMapViewModel.teeBoxCoordinate == nil)
        #expect(courseMapViewModel.holePinCoordinate == nil)
        #expect(courseMapViewModel.measuredCoordinate == nil)

        courseMapViewModel.moveToPreviousHole()

        #expect(round.currentHole == 1)
        #expect(courseMapViewModel.shotMarkers.count == 1)
        #expect(courseMapViewModel.teeBoxCoordinate?.latitude == tee.latitude)
        #expect(courseMapViewModel.holePinCoordinate?.latitude == pin.latitude)
        #expect(courseMapViewModel.measuredCoordinate?.latitude == measurement.latitude)
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
        let courseMapViewModel = CourseMapViewModel(course: course, round: round)

        #expect(courseMapViewModel.canSaveHole)
        #expect(courseMapViewModel.saveHoleButtonTitle == "Save Grant")
        #expect(courseMapViewModel.saveHoleActionAccessibilityLabel == "Save final hole for Grant and finish round")

        courseMapViewModel.saveCurrentHole()

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
        let courseMapViewModel = CourseMapViewModel(course: course)
        let initialDistance = courseMapViewModel.cameraDistance
        let teeBox = CLLocationCoordinate2D(latitude: 33.001, longitude: -84.001)

        courseMapViewModel.zoomIn()
        #expect(courseMapViewModel.cameraDistance < initialDistance)

        courseMapViewModel.zoomOut()
        #expect(courseMapViewModel.cameraDistance == initialDistance)

        courseMapViewModel.rotateLeft()
        #expect(courseMapViewModel.cameraHeading == 345)

        courseMapViewModel.rotateRight()
        #expect(courseMapViewModel.cameraHeading == 0)

        courseMapViewModel.rotateRight()
        #expect(courseMapViewModel.cameraHeading == 15)

        courseMapViewModel.resetNorth()
        #expect(courseMapViewModel.cameraHeading == 0)

        courseMapViewModel.selectionMode = .teeBox
        courseMapViewModel.selectMapLocation(at: teeBox)
        courseMapViewModel.showTeeBox()

        #expect(courseMapViewModel.cameraCenter.latitude == teeBox.latitude)
        #expect(courseMapViewModel.cameraCenter.longitude == teeBox.longitude)
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
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self])
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
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self])
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
            },
            {
              "type": "way",
              "id": 104,
              "tags": { "golf": "fairway", "ref": "1" },
              "geometry": [
                { "lat": 33.0020, "lon": -84.0010 },
                { "lat": 33.0180, "lon": -84.0010 },
                { "lat": 33.0180, "lon": -83.9990 },
                { "lat": 33.0020, "lon": -83.9990 },
                { "lat": 33.0020, "lon": -84.0010 }
              ]
            },
            {
              "type": "way",
              "id": 105,
              "tags": { "natural": "water" },
              "geometry": [
                { "lat": 33.0100, "lon": -84.0020 },
                { "lat": 33.0110, "lon": -84.0020 },
                { "lat": 33.0110, "lon": -84.0010 },
                { "lat": 33.0100, "lon": -84.0010 },
                { "lat": 33.0100, "lon": -84.0020 }
              ]
            }
          ]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(OpenStreetMapOverpassResponse.self, from: json)
        let geometryImport = OpenStreetMapGolfGeometryNormalizer().normalizedImport(courseExternalID: 42, elements: response.elements)
        let hole = try #require(geometryImport.holes.first)
        let teePoint = try #require(hole.featurePoints.first { $0.kind == .teeBox && $0.label == "Blue Tee" })
        let hazardPoint = try #require(hole.featurePoints.first { $0.kind == .hazard })
        let fairway = try #require(hole.areaFeatures.first { $0.kind == .fairway })
        let water = try #require(hole.areaFeatures.first { $0.kind == .water })

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
        #expect(fairway.coordinates.count == 5)
        #expect(water.coordinates.count == 5)
    }

    @Test func courseGeometryEditorImportsOpenStreetMapWithoutOverwritingUserAnchors() throws {
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self])
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
        let courseMapViewModel = CourseMapViewModel(
            course: CourseMapPoint(id: 42, courseName: "Example Course", clubName: "Example Club", latitude: 33.0, longitude: -84.0),
            currentHoleNumber: 1
        )

        courseMapViewModel.applyStoredHoleSetup(from: geometries)

        #expect(geometry.sourceRawValue == CourseGeometrySource.openStreetMap.rawValue)
        #expect(geometry.attribution == "© OpenStreetMap contributors, ODbL")
        #expect(hole.featurePoints.contains { $0.kind == .teeBox && $0.source == .userMapped })
        #expect(hole.featurePoints.contains { $0.kind == .teeBox && $0.source == .openStreetMap })
        #expect(hole.featurePoints.contains { $0.kind == .greenPin && $0.source == .userMapped })
        #expect(hole.greenCenterLatitude == osmGreen.latitude)
        #expect(courseMapViewModel.teeBoxCoordinate?.latitude == userTee.latitude)
        #expect(courseMapViewModel.holePinCoordinate?.latitude == userPin.latitude)
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
        let courseSearchViewModel = CourseSearchViewModel(apiKey: "test-key")

        courseSearchViewModel.selectTee(id: whiteTee.id)

        #expect(courseSearchViewModel.selectedTeeID == whiteTee.id)
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
        let courseSearchViewModel = CourseSearchViewModel(
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

        courseSearchViewModel.recordRecent(course: updatedCourse)

        #expect(courseSearchViewModel.recents.map(\.id) == [2, 1, 3])
        #expect(courseSearchViewModel.recents.first?.displayName == "Updated Club - Updated Course")
        #expect(courseSearchViewModel.recents.first?.locationText == "2 Fairway")
        #expect(store.savedRecents == courseSearchViewModel.recents)
    }

    @Test func courseSearchViewModelCapsRecentsAtTwenty() throws {
        let initialRecents = (1...20).map { id in
            CourseRecent(id: id, displayName: "Course \(id)")
        }
        let store = InMemoryCourseRecentsStore(initialRecents: initialRecents)
        let courseSearchViewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in StubGolfCourseAPIClient() },
            recentsStore: store
        )
        let newCourse = try makeAPICourse(id: 21, clubName: "Newest Club", courseName: "Newest Course")

        courseSearchViewModel.recordRecent(course: newCourse)

        #expect(courseSearchViewModel.recents.count == 20)
        #expect(courseSearchViewModel.recents.first?.id == 21)
        #expect(courseSearchViewModel.recents.map(\.id).contains(20) == false)
        #expect(store.savedRecents.count == 20)
    }

    @Test func courseSearchViewModelReportsSearchQueryPresence() {
        let courseSearchViewModel = CourseSearchViewModel(apiKey: "test-key")

        #expect(courseSearchViewModel.hasSearchQuery == false)

        courseSearchViewModel.query = "  Golden Horseshoe  "

        #expect(courseSearchViewModel.hasSearchQuery)
    }

    @Test func golfCourseNearbyRankingOrdersByDistanceAndDropsMissingCoordinates() throws {
        let user = CLLocation(latitude: 33.0, longitude: -84.0)
        let far = try makeAPICourse(id: 1, clubName: "Far", courseName: "A", latitude: 33.5, longitude: -84.0)
        let near = try makeAPICourse(id: 2, clubName: "Near", courseName: "B", latitude: 33.01, longitude: -84.0)
        let noCoord = try makeAPICourse(id: 3, clubName: "Mystery", courseName: "C")
        let ranked = GolfCourseNearbyRanking.rankedCourses([far, near, noCoord], userLocation: user)
        #expect(ranked.map(\.course.id) == [2, 1])
        #expect(ranked.count == 2)
    }

    @Test func courseSearchDistanceFormattingUsesYardsWhenVeryClose() {
        let metersForAboutOneHundredYards = 100.0 / 1.09361
        let caption = CourseSearchDistanceFormatting.caption(forMeters: metersForAboutOneHundredYards)
        #expect(caption.hasSuffix(" yds"))
    }

    @Test func courseSearchEnrichmentFetchesDetailsWhenSearchOmitsCoordinates() async throws {
        let withoutCoords = try makeAPICourse(id: 901, clubName: "Test Club", courseName: "Test Course")
        let withCoords = try makeAPICourse(
            id: 901,
            clubName: "Test Club",
            courseName: "Test Course",
            latitude: 33.0,
            longitude: -84.0
        )
        let client = StubGolfCourseAPIClient(searchResults: [withoutCoords], coursesByID: [901: withCoords])
        let courseSearchViewModel = CourseSearchViewModel(apiKey: "test-key", apiClientProvider: { _ in client })

        let enriched = try await courseSearchViewModel.enrichSearchHitsWithCoordinates([withoutCoords], api: client)

        #expect(enriched.count == 1)
        #expect(enriched[0].location.latitude == 33.0)
        #expect(enriched[0].location.longitude == -84.0)
    }

    @Test func courseSearchViewModelDeletesAndClearsRecents() {
        let store = InMemoryCourseRecentsStore(initialRecents: [
            CourseRecent(id: 1, displayName: "First Club"),
            CourseRecent(id: 2, displayName: "Second Club"),
            CourseRecent(id: 3, displayName: "Third Club")
        ])
        let courseSearchViewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in StubGolfCourseAPIClient() },
            recentsStore: store
        )

        courseSearchViewModel.deleteRecent(id: 2)

        #expect(courseSearchViewModel.recents.map(\.id) == [1, 3])
        #expect(store.savedRecents == courseSearchViewModel.recents)

        courseSearchViewModel.clearRecents()

        #expect(courseSearchViewModel.recents.isEmpty)
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
        let courseSearchViewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in apiClient },
            recentsStore: store
        )

        await courseSearchViewModel.loadCourse(id: 42)

        #expect(courseSearchViewModel.errorMessage == nil)
        #expect(courseSearchViewModel.selectedCourse?.id == 42)
        #expect(courseSearchViewModel.recents == [CourseRecent(course: course)])
        #expect(store.savedRecents == courseSearchViewModel.recents)
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
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let courseSearchViewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in apiClient },
            geometryProvider: geometryProvider
        )

        await courseSearchViewModel.loadCourse(id: 42)
        await courseSearchViewModel.ensureOpenStreetMapGeometryIfNeeded(modelContext: modelContext)

        let geometries = try modelContext.fetch(FetchDescriptor<CourseGeometry>())
        let geometry = try #require(geometries.first)

        #expect(geometryProvider.requestCount == 1)
        #expect(geometry.courseExternalID == 42)
        #expect(geometry.sourceRawValue == CourseGeometrySource.openStreetMap.rawValue)
        #expect(courseSearchViewModel.statusMessage == "Loaded OpenStreetMap geometry for 1 hole.")
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
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let cachedGeometry = CourseGeometry(
            courseExternalID: 42,
            source: .openStreetMap,
            sourceName: "OpenStreetMap",
            holes: [HoleGeometry(number: 1, greenCenterLatitude: 33.75, greenCenterLongitude: -84.39)]
        )
        let courseSearchViewModel = CourseSearchViewModel(
            apiKey: "test-key",
            apiClientProvider: { _ in apiClient },
            geometryProvider: geometryProvider
        )

        modelContext.insert(cachedGeometry)
        try modelContext.save()
        await courseSearchViewModel.loadCourse(id: 42)
        await courseSearchViewModel.ensureOpenStreetMapGeometryIfNeeded(modelContext: modelContext)

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
        let courseSearchViewModel = CourseSearchViewModel(apiKey: "test-key")

        courseSearchViewModel.save(course: apiCourse, modelContext: modelContext)

        #expect(courseSearchViewModel.errorMessage == nil)
        #expect(courseSearchViewModel.statusMessage == "Saved Example Club - Example Course.")

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
        let schema = Schema([CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self])
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
        #expect(players[0].teeName == "Blue")
        #expect(players[0].teeGender == "male")
        #expect(players[1].teeName == "Blue")
        #expect(players[1].teeGender == "male")
        #expect(players.map(\.name) == ["Grant", "Alex", "Sam", "Jo", "Lee", "Kai", "Ari", "Bea"])
        #expect(firstScores.map(\.holeNumber) == [1, 2])
        #expect(firstScores[0].par == 4)
        #expect(firstScores[1].par == 5)
    }

    /// Regression guard: large `GolfRound` libraries with per-player `RoundPlayer.teeName` / `teeGender`
    /// must fetch quickly (isolates SwiftData from SwiftUI tab freezes).
    @Test func roundsLibraryInMemoryFetchesManyRoundsWithPerPlayerTees() throws {
        let holes = (1...18).map { n in
            RoundSetupHole(number: n, par: 4, yardage: 400, handicap: n)
        }
        let tee = RoundSetupTee(gender: "male", name: "Blue", totalYards: 7200, parTotal: 72, holes: holes)
        let course = RoundSetupCourse(
            externalID: 9901,
            clubName: "Stress Club",
            courseName: "Stress Course",
            latitude: 33.75,
            longitude: -84.39
        )
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let builder = RoundBuilder()

        for i in 0..<45 {
            let round = builder.makeRound(
                course: course,
                tee: tee,
                scoringMode: .strokePlay,
                playerNames: ["Alpha", "Bravo"],
                startedAt: Date().addingTimeInterval(-Double(i) * 3600)
            )
            if i % 4 != 0 {
                round.completedAt = .now
            }
            modelContext.insert(round)
        }
        try modelContext.save()

        let descriptor = FetchDescriptor<GolfRound>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        let fetched = try modelContext.fetch(descriptor)
        #expect(fetched.count == 45)
        let firstRound = try #require(fetched.first)
        let firstPlayer = try #require(firstRound.players.first)
        #expect(firstPlayer.teeName == "Blue")
        #expect(firstPlayer.resolvedTeeName(in: firstRound) == "Blue")
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
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
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
        let scorecardViewModel = ScorecardViewModel(round: round)

        #expect(scorecardViewModel.frontNineHoles == Array(1...9))
        #expect(scorecardViewModel.backNineHoles == Array(10...18))
        #expect(scorecardViewModel.frontNineSummaryText == "Par 36 · 3600 yds")
        #expect(scorecardViewModel.backNineSummaryText == "Par 45 · 4500 yds")
        #expect(scorecardViewModel.roundSummaryText == "Par 81 · 8100 yds")
    }

    @Test func scorecardViewModelAddsDeletesAndReordersPlayers() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let gp = RoundPlayer(
            name: "Gp.",
            displayOrder: 0,
            scores: [
                HoleScore(holeNumber: 1, par: 4, yardage: 421, handicap: 3),
                HoleScore(holeNumber: 2, par: 3, yardage: 180, handicap: 17)
            ]
        )
        let toehead = RoundPlayer(
            name: "Toehead",
            displayOrder: 1,
            scores: [
                HoleScore(holeNumber: 1, par: 4, yardage: 421, handicap: 3),
                HoleScore(holeNumber: 2, par: 3, yardage: 180, handicap: 17)
            ]
        )
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male",
            players: [gp, toehead]
        )
        let scorecardViewModel = ScorecardViewModel(round: round)

        modelContext.insert(round)
        try modelContext.save()

        scorecardViewModel.addPlayer(named: "Bill", modelContext: modelContext)
        let bill = try #require(scorecardViewModel.players.first { $0.name == "Bill" })

        #expect(scorecardViewModel.players.map(\.name) == ["Gp.", "Toehead", "Bill"])
        #expect(bill.scores.sorted { $0.holeNumber < $1.holeNumber }.map(\.yardage) == [421, 180])
        #expect(scorecardViewModel.primaryPlayerName == "Bill")

        scorecardViewModel.movePlayer(gp.id, to: 3, modelContext: modelContext)
        #expect(scorecardViewModel.players.map(\.name) == ["Toehead", "Bill", "Gp."])

        scorecardViewModel.deletePlayer(bill, modelContext: modelContext)
        #expect(scorecardViewModel.players.map(\.name) == ["Toehead", "Gp."])
        #expect(scorecardViewModel.primaryPlayerName == "Toehead")
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
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let roundsListViewModel = RoundsListViewModel()

        modelContext.insert(round)
        try modelContext.save()

        #expect(roundsListViewModel.dateText(for: round) == "Monday July 7, 2025")

        roundsListViewModel.delete(round, modelContext: modelContext)

        let rounds = try modelContext.fetch(FetchDescriptor<GolfRound>())
        #expect(rounds.isEmpty)
    }

    @Test func defaultGolfClubTemplatesBuildActiveBagInOrder() {
        let clubs = GolfClubTemplate.defaultBag.map(GolfClub.init(template:))
        let activeValues = clubs.map(\.isActive)

        #expect(clubs.count == 14)
        #expect(clubs.first?.name == "Driver")
        #expect(clubs.first?.carryYards == 245)
        #expect(clubs.first?.totalYards == 245 + GolfClub.rolloutBeyondCarryYards)
        #expect(clubs.last?.kind == .putter)
        #expect(clubs.last?.totalYards == 0)
        #expect(clubs.map(\.displayOrder) == Array(0..<14))
        #expect(activeValues == Array(repeating: true, count: clubs.count))
    }

    @Test func bagCatalogListsMissingLongIronsAgainstStarterBag() {
        let starter = GolfClubTemplate.defaultBag.map(GolfClub.init(template:))
        let available = GolfClubTemplate.templatesAvailableToAdd(to: starter)
        #expect(available.contains { $0.name == "3 Iron" })
        #expect(available.contains { $0.name == "4 Iron" })
    }

    @Test func bagCatalogSuggestsTemplatesStrictlyBetweenCarryGap() {
        let long = GolfClub(kind: .fairwayWood, name: "3 Wood", carryYards: 220, totalYards: 235, displayOrder: 0)
        let short = GolfClub(kind: .iron, name: "4 Iron", carryYards: 180, totalYards: 195, displayOrder: 1)
        let suggested = GolfClubTemplate.templatesSuggestedForCarryGap(
            longerCarryYards: 220,
            shorterCarryYards: 180,
            existingClubs: [long, short]
        )
        #expect(suggested.contains { $0.name == "3 Hybrid" })
        #expect(suggested.allSatisfy { $0.carryYards < 220 && $0.carryYards > 180 })
    }

    @Test func bagDistanceCoverageFlagsLargeCarryGap() {
        let long = GolfClub(kind: .driver, name: "Driver", carryYards: 300, totalYards: 315, displayOrder: 0)
        let short = GolfClub(kind: .wedge, name: "SW", carryYards: 80, totalYards: 95, displayOrder: 1)
        let summary = BagDistanceCoverage.summary(for: [long, short])
        #expect(summary.level == .caution)
        #expect(summary.title == "Wide gap in your bag")
    }

    @Test func bagDistanceCoverageOkForReasonableStarterSpacing() {
        let clubs = GolfClubTemplate.defaultBag.map(GolfClub.init(template:))
        let summary = BagDistanceCoverage.summary(for: clubs)
        #expect(summary.level == .ok)
    }

    @Test func bagCarryGapHighlightMarksShorterClubAfterWideDrop() {
        let w3 = GolfClub(kind: .fairwayWood, name: "3 Wood", carryYards: 220, totalYards: 235, displayOrder: 0)
        let i4 = GolfClub(kind: .iron, name: "4 Iron", carryYards: 180, totalYards: 195, displayOrder: 1)
        let ids = BagDistanceCoverage.clubIDsFollowingCarryGap(in: [w3, i4])
        #expect(ids == Set([i4.id]))
    }

    @Test func bagCarryGapHighlightIgnoresDropJustBelowThreshold() {
        let a = GolfClub(kind: .iron, name: "Long", carryYards: 200, totalYards: 215, displayOrder: 0)
        let b = GolfClub(kind: .iron, name: "Short", carryYards: 175, totalYards: 190, displayOrder: 1)
        let ids = BagDistanceCoverage.clubIDsFollowingCarryGap(in: [a, b])
        #expect(ids.isEmpty)
    }

    @Test func bagViewModelSeedsDefaultBagOnlyOnce() throws {
        let schema = Schema([GolfClub.self, ShotRecord.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let bagViewModel = BagViewModel()

        bagViewModel.seedDefaultBagIfNeeded(existingClubs: [], modelContext: modelContext)
        var clubs = try modelContext.fetch(
            FetchDescriptor<GolfClub>(
                sortBy: [
                    SortDescriptor(\.carryYards, order: .reverse),
                    SortDescriptor(\.name)
                ]
            )
        )

        #expect(clubs.count == 14)
        #expect(clubs.first?.name == "Driver")
        #expect(bagViewModel.statusMessage == "Loaded Woody's starter bag.")

        bagViewModel.seedDefaultBagIfNeeded(existingClubs: clubs, modelContext: modelContext)
        clubs = try modelContext.fetch(FetchDescriptor<GolfClub>())

        #expect(clubs.count == 14)
    }

    @Test func roundDataBackbonePersistsProfilesShotsClubsAndWeather() throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
        let profile = PlayerProfile(displayName: "Grant", contactIdentifier: "contact-1", avatarSource: .contacts)
        let club = GolfClub(template: GolfClubTemplate.defaultBag[0])
        let score = HoleScore(holeNumber: 1, par: 4)
        let player = RoundPlayer(playerProfile: profile, name: "Grant", displayOrder: 0, scores: [score])
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
        let weatherSnapshot = RoundWeatherSnapshot(
            round: round,
            latitude: 33.0,
            longitude: -84.0,
            symbolName: "sun.max.fill",
            temperatureFahrenheit: 72,
            windSpeedMilesPerHour: 8
        )
        let shot = ShotRecord(
            round: round,
            player: player,
            club: club,
            weatherSnapshot: weatherSnapshot,
            holeNumber: 1,
            shotNumber: 1,
            startCoordinate: CLLocationCoordinate2D(latitude: 33.0, longitude: -84.0),
            endCoordinate: CLLocationCoordinate2D(latitude: 33.001, longitude: -84.0),
            distanceYards: 121,
            lie: .tee,
            result: .fairwayHit,
            source: .gps
        )

        modelContext.insert(profile)
        modelContext.insert(club)
        modelContext.insert(round)
        modelContext.insert(weatherSnapshot)
        modelContext.insert(shot)
        try modelContext.save()

        let fetchedRound = try #require(try modelContext.fetch(FetchDescriptor<GolfRound>()).first)
        let fetchedShot = try #require(try modelContext.fetch(FetchDescriptor<ShotRecord>()).first)
        let fetchedWeather = try #require(try modelContext.fetch(FetchDescriptor<RoundWeatherSnapshot>()).first)
        let fetchedPlayer = try #require(fetchedRound.players.first)

        #expect(fetchedRound.shotRecords.count == 1)
        #expect(fetchedRound.weatherSnapshots.count == 1)
        #expect(fetchedPlayer.playerProfile?.displayName == "Grant")
        #expect(profile.avatarSource == .contacts)
        #expect(fetchedShot.clubNameSnapshot == "Driver")
        #expect(fetchedShot.lie == .tee)
        #expect(fetchedShot.result == .fairwayHit)
        #expect(fetchedShot.source == .gps)
        #expect(fetchedShot.club === club)
        #expect(fetchedWeather.temperatureText == "72°")
        #expect(fetchedWeather.source == .weatherKit)
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
        let weatherViewModel = WeatherViewModel(provider: provider)

        await weatherViewModel.loadWeather(for: round)
        await weatherViewModel.loadWeather(for: round)

        let summary = try #require(weatherViewModel.summary(for: round))
        #expect(summary.symbolName == "sun.max.fill")
        #expect(summary.temperatureText == "72°")
        #expect(provider.requestCount == 1)

        weatherViewModel.removeWeather(for: round.id)

        #expect(weatherViewModel.summary(for: round) == nil)
    }

    @Test func weatherViewModelPersistsAndReusesRoundSnapshot() async throws {
        let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = container.mainContext
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
        let weatherViewModel = WeatherViewModel(provider: provider)

        modelContext.insert(round)
        try modelContext.save()
        await weatherViewModel.loadWeather(for: round, modelContext: modelContext)
        weatherViewModel.removeWeather(for: round.id)
        await weatherViewModel.loadWeather(for: round, modelContext: modelContext)

        let snapshots = try modelContext.fetch(FetchDescriptor<RoundWeatherSnapshot>())
        let summary = try #require(weatherViewModel.summary(for: round))

        #expect(snapshots.count == 1)
        #expect(snapshots.first?.round === round)
        #expect(snapshots.first?.temperatureText == "72°")
        #expect(summary.temperatureText == "72°")
        #expect(summary.windText == "Wind 8 mph")
        #expect(provider.requestCount == 1)
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
        let weatherViewModel = WeatherViewModel(provider: provider)

        await weatherViewModel.loadWeather(for: round)

        #expect(weatherViewModel.summary(for: round) == nil)
        #expect(weatherViewModel.errorText(for: round) == "Weather unavailable.")
    }

    @Test func weatherViewModelHidesSystemWeatherErrors() async throws {
        let round = GolfRound(
            courseExternalID: 42,
            courseName: "Example Course",
            clubName: "Example Club",
            courseLatitude: 33.0,
            courseLongitude: -84.0,
            teeName: "Blue",
            teeGender: "male"
        )
        let provider = StubWeatherProvider(error: StubWeatherProviderError.systemDaemon)
        let weatherViewModel = WeatherViewModel(provider: provider)

        await weatherViewModel.loadWeather(for: round)

        #expect(weatherViewModel.summary(for: round) == nil)
        #expect(weatherViewModel.errorText(for: round) == "Weather unavailable.")
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
        return WeatherSummary(
            symbolName: "sun.max.fill",
            temperatureFahrenheit: 72,
            conditionText: "Sunny",
            windSpeedMilesPerHour: 8,
            windDirectionDegrees: 180
        )
    }
}

private enum StubWeatherProviderError: LocalizedError {
    case unavailable
    case systemDaemon

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Weather unavailable."
        case .systemDaemon:
            "The operation couldn't be completed. (WeatherDaemon.WDS.JWTAuthenticator-ServiceListener.Errors error 2.)"
        }
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
