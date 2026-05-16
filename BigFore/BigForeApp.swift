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
    var sharedModelContainer: ModelContainer = {
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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
