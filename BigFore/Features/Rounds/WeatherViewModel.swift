import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WeatherViewModel {
    private static let unavailableMessage = "Weather unavailable."

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

    func loadWeather(for round: GolfRound, modelContext: ModelContext? = nil) async {
        if let snapshot = latestSnapshot(for: round) {
            summaries[round.id] = WeatherSummary(snapshot: snapshot)
            errors[round.id] = nil
            return
        }

        guard summaries[round.id] == nil,
              !loadingRoundIDs.contains(round.id),
              let latitude = round.courseLatitude,
              let longitude = round.courseLongitude else {
            return
        }

        loadingRoundIDs.insert(round.id)
        defer { loadingRoundIDs.remove(round.id) }

        do {
            let summary = try await provider.weather(for: WeatherRequest(
                latitude: latitude,
                longitude: longitude,
                date: round.startedAt
            ))
            summaries[round.id] = summary
            persistSnapshot(summary, for: round, latitude: latitude, longitude: longitude, modelContext: modelContext)
            errors[round.id] = nil
        } catch {
            summaries[round.id] = nil
            errors[round.id] = Self.unavailableMessage
        }
    }

    func removeWeather(for roundID: UUID) {
        summaries[roundID] = nil
        errors[roundID] = nil
        loadingRoundIDs.remove(roundID)
    }

    private func persistSnapshot(
        _ summary: WeatherSummary,
        for round: GolfRound,
        latitude: Double,
        longitude: Double,
        modelContext: ModelContext?
    ) {
        guard let modelContext else {
            return
        }

        let snapshot = RoundWeatherSnapshot(
            round: round,
            observedAt: .now,
            latitude: latitude,
            longitude: longitude,
            symbolName: summary.symbolName,
            conditionText: summary.conditionText,
            temperatureFahrenheit: summary.temperatureFahrenheit,
            windSpeedMilesPerHour: summary.windSpeedMilesPerHour,
            windDirectionDegrees: summary.windDirectionDegrees
        )

        modelContext.insert(snapshot)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            summaries[round.id] = nil
            errors[round.id] = "Could not save weather: \(error.localizedDescription)"
        }
    }

    private func latestSnapshot(for round: GolfRound) -> RoundWeatherSnapshot? {
        round.weatherSnapshots.max { $0.observedAt < $1.observedAt }
    }
}
