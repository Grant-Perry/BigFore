import Foundation
import Observation

@MainActor
@Observable
final class WeatherViewModel {
    private(set) var summaries: [UUID: WeatherSummary] = [:]
    private(set) var errors: [UUID: String] = [:]
    @ObservationIgnored private var loadingRoundIDs: Set<UUID> = []
    @ObservationIgnored private let provider: any WeatherProviding

    init(provider: any WeatherProviding = WeatherKitProvider()) {
        self.provider = provider
    }

    func summary(for round: GolfRound) -> WeatherSummary? {
        summaries[round.id]
    }

    func errorText(for round: GolfRound) -> String? {
        errors[round.id]
    }

    func loadWeather(for round: GolfRound) async {
        guard summaries[round.id] == nil,
              !loadingRoundIDs.contains(round.id),
              let latitude = round.courseLatitude,
              let longitude = round.courseLongitude else {
            return
        }

        loadingRoundIDs.insert(round.id)
        defer { loadingRoundIDs.remove(round.id) }

        do {
            summaries[round.id] = try await provider.weather(for: WeatherRequest(
                latitude: latitude,
                longitude: longitude,
                date: round.startedAt
            ))
            errors[round.id] = nil
        } catch {
            summaries[round.id] = nil
            errors[round.id] = error.localizedDescription
        }
    }

    func removeWeather(for roundID: UUID) {
        summaries[roundID] = nil
        errors[roundID] = nil
        loadingRoundIDs.remove(roundID)
    }
}
