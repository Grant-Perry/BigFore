//
//  ContentView.swift
//  BigFore
//
//  Created by Gp. on 5/12/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CourseSearchView()
                .tabItem {
                    Label("Courses", systemImage: "map")
                }

            RoundsListView()
                .tabItem {
                    Label("Rounds", systemImage: "scorecard")
                }

            SavedCoursesView()
                .tabItem {
                    Label("Saved", systemImage: "tray.full")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self], inMemory: true)
}
