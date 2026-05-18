import CoreLocation
import Foundation
import SwiftData
import SwiftUI
import WeatherKit

struct WeatherSummary: Equatable {
    let symbolName: String
    let temperatureFahrenheit: Double?
    let conditionText: String?
    let windSpeedMilesPerHour: Double?
    let windDirectionDegrees: Double?

    var temperatureText: String {
        guard let temperatureFahrenheit else {
            return "--"
        }

        return "\(temperatureFahrenheit.rounded().formatted(.number.precision(.fractionLength(0))))°"
    }

    var windText: String? {
        guard let windSpeedMilesPerHour else {
            return nil
        }

        let speed = windSpeedMilesPerHour.rounded().formatted(.number.precision(.fractionLength(0)))
        return "Wind \(speed) mph"
    }

    init(
        symbolName: String,
        temperatureFahrenheit: Double? = nil,
        conditionText: String? = nil,
        windSpeedMilesPerHour: Double? = nil,
        windDirectionDegrees: Double? = nil
    ) {
        self.symbolName = symbolName
        self.temperatureFahrenheit = temperatureFahrenheit
        self.conditionText = conditionText
        self.windSpeedMilesPerHour = windSpeedMilesPerHour
        self.windDirectionDegrees = windDirectionDegrees
    }
}

extension WeatherSummary {
    init(snapshot: RoundWeatherSnapshot) {
        self.init(
            symbolName: snapshot.symbolName,
            temperatureFahrenheit: snapshot.temperatureFahrenheit,
            conditionText: snapshot.conditionText,
            windSpeedMilesPerHour: snapshot.windSpeedMilesPerHour,
            windDirectionDegrees: snapshot.windDirectionDegrees
        )
    }
}

struct WeatherRequest: Hashable {
    let latitude: Double
    let longitude: Double
    let date: Date
}

@MainActor
protocol WeatherProviding {
    func weather(for request: WeatherRequest) async throws -> WeatherSummary
}

@MainActor
struct WeatherKitProvider: WeatherProviding {
    private let service: WeatherService

    init(service: WeatherService = .shared) {
        self.service = service
    }

    func weather(for request: WeatherRequest) async throws -> WeatherSummary {
        let location = CLLocation(latitude: request.latitude, longitude: request.longitude)
        let weather = try await service.weather(for: location)
        let currentWeather = weather.currentWeather
        let temperature = currentWeather.temperature.converted(to: .fahrenheit)
        let windSpeed = currentWeather.wind.speed.converted(to: .milesPerHour)

        return WeatherSummary(
            symbolName: currentWeather.symbolName,
            temperatureFahrenheit: temperature.value,
            conditionText: currentWeather.condition.description,
            windSpeedMilesPerHour: windSpeed.value,
            windDirectionDegrees: currentWeather.wind.direction.converted(to: .degrees).value
        )
    }
}

// MARK: - WeatherKit symbol (multicolor SF Symbol)

/// Renders a WeatherKit `symbolName` with Apple’s multicolor treatment when available.
struct WeatherGlyph: View {
    let symbolName: String
    var font: Font = .title3

    var body: some View {
        Image(systemName: symbolName)
            .font(font)
            .symbolRenderingMode(.multicolor)
            .accessibilityHidden(true)
    }
}
