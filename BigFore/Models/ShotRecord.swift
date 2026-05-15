import CoreLocation
import Foundation
import SwiftData

@Model
final class ShotRecord {
    var id: UUID
    var round: GolfRound?
    var player: RoundPlayer?
    var club: GolfClub?
    var weatherSnapshot: RoundWeatherSnapshot?
    var holeNumber: Int
    var shotNumber: Int
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    var startAltitude: Double?
    var endAltitude: Double?
    var distanceYards: Int
    var clubNameSnapshot: String?
    var lieRawValue: String
    var resultRawValue: String
    var penaltyStrokes: Int
    var notes: String
    var sourceRawValue: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        round: GolfRound? = nil,
        player: RoundPlayer? = nil,
        club: GolfClub? = nil,
        weatherSnapshot: RoundWeatherSnapshot? = nil,
        holeNumber: Int,
        shotNumber: Int,
        startCoordinate: CLLocationCoordinate2D,
        endCoordinate: CLLocationCoordinate2D,
        startAltitude: Double? = nil,
        endAltitude: Double? = nil,
        distanceYards: Int,
        clubNameSnapshot: String? = nil,
        lie: ShotLie = .unknown,
        result: ShotResult = .unknown,
        penaltyStrokes: Int = 0,
        notes: String = "",
        source: ShotRecordSource = .manualMap,
        createdAt: Date = .now
    ) {
        self.id = id
        self.round = round
        self.player = player
        self.club = club
        self.weatherSnapshot = weatherSnapshot
        self.holeNumber = holeNumber
        self.shotNumber = shotNumber
        self.startLatitude = startCoordinate.latitude
        self.startLongitude = startCoordinate.longitude
        self.endLatitude = endCoordinate.latitude
        self.endLongitude = endCoordinate.longitude
        self.startAltitude = startAltitude
        self.endAltitude = endAltitude
        self.distanceYards = distanceYards
        self.clubNameSnapshot = clubNameSnapshot ?? club?.name
        self.lieRawValue = lie.rawValue
        self.resultRawValue = result.rawValue
        self.penaltyStrokes = penaltyStrokes
        self.notes = notes
        self.sourceRawValue = source.rawValue
        self.createdAt = createdAt
    }
}

extension ShotRecord {
    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }

    var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }

    var lie: ShotLie {
        get { ShotLie(rawValue: lieRawValue) ?? .unknown }
        set { lieRawValue = newValue.rawValue }
    }

    var result: ShotResult {
        get { ShotResult(rawValue: resultRawValue) ?? .unknown }
        set { resultRawValue = newValue.rawValue }
    }

    var source: ShotRecordSource {
        get { ShotRecordSource(rawValue: sourceRawValue) ?? .manualMap }
        set { sourceRawValue = newValue.rawValue }
    }
}
