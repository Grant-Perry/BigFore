import Foundation
import SwiftData

@Model
final class RoundWeatherSnapshot {
    var id: UUID
    var round: GolfRound?
    var observedAt: Date
    var latitude: Double
    var longitude: Double
    var symbolName: String
    var conditionText: String?
    var temperatureFahrenheit: Double?
    var windSpeedMilesPerHour: Double?
    var windGustMilesPerHour: Double?
    var windDirectionDegrees: Double?
    var precipitationChance: Double?
    var humidity: Double?
    var sourceRawValue: String
    var attribution: String?
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \ShotRecord.weatherSnapshot) var shotRecords: [ShotRecord]

    init(
        id: UUID = UUID(),
        round: GolfRound? = nil,
        observedAt: Date = .now,
        latitude: Double,
        longitude: Double,
        symbolName: String,
        conditionText: String? = nil,
        temperatureFahrenheit: Double? = nil,
        windSpeedMilesPerHour: Double? = nil,
        windGustMilesPerHour: Double? = nil,
        windDirectionDegrees: Double? = nil,
        precipitationChance: Double? = nil,
        humidity: Double? = nil,
        source: RoundWeatherSnapshotSource = .weatherKit,
        attribution: String? = nil,
        createdAt: Date = .now,
        shotRecords: [ShotRecord] = []
    ) {
        self.id = id
        self.round = round
        self.observedAt = observedAt
        self.latitude = latitude
        self.longitude = longitude
        self.symbolName = symbolName
        self.conditionText = conditionText
        self.temperatureFahrenheit = temperatureFahrenheit
        self.windSpeedMilesPerHour = windSpeedMilesPerHour
        self.windGustMilesPerHour = windGustMilesPerHour
        self.windDirectionDegrees = windDirectionDegrees
        self.precipitationChance = precipitationChance
        self.humidity = humidity
        self.sourceRawValue = source.rawValue
        self.attribution = attribution
        self.createdAt = createdAt
        self.shotRecords = shotRecords
    }
}

extension RoundWeatherSnapshot {
    var source: RoundWeatherSnapshotSource {
        get { RoundWeatherSnapshotSource(rawValue: sourceRawValue) ?? .weatherKit }
        set { sourceRawValue = newValue.rawValue }
    }

    var temperatureText: String? {
        guard let temperatureFahrenheit else {
            return nil
        }

        return "\(temperatureFahrenheit.rounded().formatted(.number.precision(.fractionLength(0))))°"
    }
}
