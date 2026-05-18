import CoreLocation
import MapKit
import SwiftData
import SwiftUI

// MARK: - Round recap (completed rounds)

struct RoundRecapView: View {
    let round: GolfRound

    @Environment(\.modelContext) private var modelContext
    @State private var selectedHole: Int = 1
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var weatherViewModel = WeatherViewModel()

    private let scoring = RoundScoring()
    private let listDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var maxHole: Int {
        let fromScores = round.players.flatMap(\.scores).map(\.holeNumber)
        let fromShots = round.shotRecords.map(\.holeNumber)
        let upperBound = max(fromScores.max() ?? 0, fromShots.max() ?? 0, 1)
        return min(max(upperBound, 1), 18)
    }

    private var shotsOnHole: [ShotRecord] {
        round.shotRecords
            .filter { $0.holeNumber == selectedHole }
            .sorted { lhs, rhs in
                let lo = lhs.player?.displayOrder ?? 0
                let ro = rhs.player?.displayOrder ?? 0
                if lo != ro { return lo < ro }
                return lhs.shotNumber < rhs.shotNumber
            }
    }

    private var latestWeatherSnapshot: RoundWeatherSnapshot? {
        round.weatherSnapshots.max { $0.observedAt < $1.observedAt }
    }

    var body: some View {
        Group {
            if round.isComplete {
                recapContent
            } else {
                ContentUnavailableView(
                    "Round still open",
                    systemImage: "flag.checkered",
                    description: Text("Finish the round to see hole-by-hole recap, shots, and weather.")
                )
            }
        }
        .navigationTitle("Round recap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ScorecardView(round: round)
                } label: {
                    Label("Scorecard", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .task(id: round.id) {
            await weatherViewModel.loadWeather(for: round, modelContext: modelContext)
        }
    }

    private var recapContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                headerCard

                if let snapshot = latestWeatherSnapshot {
                    weatherCard(snapshot: snapshot)
                } else if let summary = weatherViewModel.summary(for: round) {
                    weatherLiveCard(summary: summary)
                } else if let err = weatherViewModel.errorText(for: round) {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                holePicker

                scoresForHoleCard

                if CourseMapPoint(round: round) != nil {
                    recapMapCard
                } else {
                    ContentUnavailableView(
                        "No course pin",
                        systemImage: "mappin.slash",
                        description: Text("This round has no saved course coordinates, so the map is unavailable.")
                    )
                    .frame(height: 160)
                }

                shotsListCard
            }
            .padding(.horizontal, BigForeDesign.Spacing.large)
            .padding(.vertical, BigForeDesign.Spacing.medium)
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            selectedHole = min(max(round.currentHole, 1), maxHole)
            updateMapCamera(animated: false)
        }
        .onChange(of: selectedHole) { _, _ in
            updateMapCamera(animated: true)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Text(round.courseName)
                .font(.title2.weight(.semibold))
            Text("\(listDateFormatter.string(from: round.startedAt)) · \(round.teeName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(round.scoringMode.title)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weatherCard(snapshot: RoundWeatherSnapshot) -> some View {
        let summary = WeatherSummary(snapshot: snapshot)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Conditions (saved)")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                WeatherGlyph(symbolName: summary.symbolName, font: .title)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.temperatureText)
                        .font(.headline)
                    if let conditionText = summary.conditionText {
                        Text(conditionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let windText = summary.windText {
                        Text(windText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            Text("Recorded \(listDateFormatter.string(from: snapshot.observedAt))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(BigForeDesign.Spacing.medium)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
    }

    private func weatherLiveCard(summary: WeatherSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conditions")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                WeatherGlyph(symbolName: summary.symbolName, font: .title)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.temperatureText)
                        .font(.headline)
                    if let windText = summary.windText {
                        Text(windText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(BigForeDesign.Spacing.medium)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
    }

    private var holePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hole")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: BigForeDesign.Spacing.large) {
                Button {
                    selectedHole = max(1, selectedHole - 1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(selectedHole <= 1)
                .accessibilityLabel("Previous hole")

                Text("Hole \(selectedHole)")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .frame(maxWidth: .infinity)

                Button {
                    selectedHole = min(maxHole, selectedHole + 1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .disabled(selectedHole >= maxHole)
                .accessibilityLabel("Next hole")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Hole \(selectedHole) of \(maxHole)")
        }
    }

    private var scoresForHoleCard: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Text("Scorecard")
                .font(.subheadline.weight(.semibold))
            ForEach(scoring.sortedPlayers(for: round), id: \.id) { player in
                if let score = player.scores.first(where: { $0.holeNumber == selectedHole }) {
                    let rel = scoring.scoreRelativeToPar(for: score)
                    HStack {
                        Text(player.name)
                            .font(.body.weight(.medium))
                        Spacer()
                        if score.strokes > 0 {
                            Text("\(score.strokes) / par \(score.par)")
                            if let rel {
                                Text(scoring.relativeText(rel))
                                    .foregroundStyle(rel > 0 ? .orange : (rel < 0 ? .green : .secondary))
                            }
                            if let putts = score.putts {
                                Text("· \(putts) putts")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(BigForeDesign.Spacing.medium)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
    }

    private var recapMapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shots on map")
                .font(.subheadline.weight(.semibold))
            RoundRecapMapView(
                round: round,
                holeNumber: selectedHole,
                shots: shotsOnHole,
                position: $mapPosition
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        }
    }

    private var shotsListCard: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Text("Tracked shots")
                .font(.subheadline.weight(.semibold))
            if shotsOnHole.isEmpty {
                Text("No mapped shots for this hole.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shotsOnHole, id: \.id) { shot in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(shot.player?.name ?? "Player") · shot \(shot.shotNumber)")
                            .font(.caption.weight(.semibold))
                        Text("\(shot.clubNameSnapshot ?? shot.club?.name ?? "Club") · \(shot.distanceYards) yd")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if shot.lie != .unknown || shot.result != .unknown {
                            Text("\(shot.lie.rawValue.capitalized) → \(shot.result.rawValue.replacingOccurrences(of: "_", with: " "))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(BigForeDesign.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
    }

    private func updateMapCamera(animated: Bool) {
        guard let course = CourseMapPoint(round: round) else {
            return
        }
        let region = Self.boundingRegion(course: course.coordinate, shots: shotsOnHole)
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                mapPosition = .region(region)
            }
        } else {
            mapPosition = .region(region)
        }
    }

    private static func boundingRegion(course: CLLocationCoordinate2D, shots: [ShotRecord]) -> MKCoordinateRegion {
        var coords: [CLLocationCoordinate2D] = [course]
        for shot in shots {
            coords.append(shot.startCoordinate)
            coords.append(shot.endCoordinate)
        }
        coords = coords.filter { CLLocationCoordinate2DIsValid($0) }
        guard let first = coords.first else {
            return MKCoordinateRegion(center: course, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015))
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for c in coords.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = max((maxLat - minLat) * 1.45, 0.004)
        let lonDelta = max((maxLon - minLon) * 1.45, 0.004)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}

// MARK: - Read-only map

private struct RoundRecapMapView: View {
    let round: GolfRound
    let holeNumber: Int
    let shots: [ShotRecord]
    @Binding var position: MapCameraPosition

    var body: some View {
        if let course = CourseMapPoint(round: round) {
            Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
                Marker(course.courseName, coordinate: course.coordinate)

                ForEach(shots, id: \.id) { shot in
                    MapPolyline(coordinates: [shot.startCoordinate, shot.endCoordinate])
                        .stroke(BigForeDesign.Palette.shotLine, lineWidth: 3)

                    Annotation("Start", coordinate: shot.startCoordinate, anchor: .center) {
                        Circle()
                            .fill(BigForeDesign.Palette.tee.opacity(0.9))
                            .frame(width: 10, height: 10)
                            .accessibilityLabel("Shot \(shot.shotNumber) start")
                    }

                    Annotation("Ball", coordinate: shot.endCoordinate, anchor: .center) {
                        CourseMapShotBallMarkerView(
                            shotNumber: shot.shotNumber,
                            isSelected: false
                        )
                        .accessibilityLabel("Shot \(shot.shotNumber) end")
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
        }
    }
}

#Preview("Round recap") {
    let schema = Schema([GolfRound.self, RoundPlayer.self, HoleScore.self, ShotRecord.self, RoundWeatherSnapshot.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    let round = GolfRound(
        courseExternalID: 1,
        courseName: "BigFore Test",
        clubName: "Test Club",
        courseLatitude: 37.78,
        courseLongitude: -122.42,
        teeName: "Blue",
        teeGender: "M",
        startedAt: .now,
        completedAt: .now,
        currentHole: 9,
        players: []
    )
    let score = HoleScore(holeNumber: 1, par: 4, yardage: 400, strokes: 4, putts: 2)
    let player = RoundPlayer(name: "Gp.", displayOrder: 0, scores: [score])
    player.round = round
    score.player = player
    round.players = [player]
    let shot = ShotRecord(
        round: round,
        player: player,
        holeNumber: 1,
        shotNumber: 1,
        startCoordinate: CLLocationCoordinate2D(latitude: 37.781, longitude: -122.419),
        endCoordinate: CLLocationCoordinate2D(latitude: 37.780, longitude: -122.418),
        distanceYards: 245,
        clubNameSnapshot: "Driver"
    )
    container.mainContext.insert(round)
    container.mainContext.insert(shot)
    _ = shot.id
    return NavigationStack {
        RoundRecapView(round: round)
    }
    .modelContainer(container)
}
