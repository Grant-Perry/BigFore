//
//  BigForeApp.swift
//  BigFore
//
//  Created by Gp. on 5/12/26.
//

import SwiftUI
import SwiftData

@main
struct BigForeApp: App {
    /// UI tests pass `-BigForeUITestInMemory` so each run uses a fresh store (no device migration / stale DB).
    private static func makeSharedModelContainer() throws -> ModelContainer {
        let schema = Schema([
            GolfCourse.self,
            GolfCourseTee.self,
            GolfCourseHole.self,
            CourseGeometry.self,
            HoleGeometry.self,
            CourseMapFeaturePoint.self,
            CourseMapAreaFeature.self,
            GolfRound.self,
            RoundPlayer.self,
            HoleScore.self,
            PlayerProfile.self,
            GolfClub.self,
            ShotRecord.self,
            RoundWeatherSnapshot.self,
        ])
        let inMemory = ProcessInfo.processInfo.arguments.contains("-BigForeUITestInMemory")
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    var sharedModelContainer: ModelContainer = {
        do {
            return try Self.makeSharedModelContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
