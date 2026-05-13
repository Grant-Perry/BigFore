import CoreLocation
import Foundation
import WeatherKit

struct WeatherSummary: Equatable {
    let symbolName: String
    let temperatureText: String
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
        let temperature = weather.currentWeather.temperature.converted(to: .fahrenheit)

        return WeatherSummary(
            symbolName: weather.currentWeather.symbolName,
            temperatureText: "\(temperature.value.rounded().formatted(.number.precision(.fractionLength(0))))°"
        )
    }
}
