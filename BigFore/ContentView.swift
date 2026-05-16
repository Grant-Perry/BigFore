//
//  ContentView.swift
//  BigFore
//
//  Created by Gp. on 5/12/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = BigForeTab.play
    @AppStorage("playHome.prefersDarkMode") private var prefersDarkMode = false

    var body: some View {
        TabView(selection: $selectedTab) {
            PlayHomeView(
                openCourseSearch: { selectedTab = .find },
                openSavedCourses: { selectedTab = .saved },
                openRounds: { selectedTab = .rounds },
                openBag: { selectedTab = .bag }
            )
            .tabItem {
                Label("Play", systemImage: "figure.golf")
            }
            .tag(BigForeTab.play)

            CourseSearchView()
                .tabItem {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .tag(BigForeTab.find)

            RoundsListView()
                .tabItem {
                    Label("Rounds", systemImage: "scorecard")
                }
                .tag(BigForeTab.rounds)

            BagView(onDismiss: { selectedTab = .play })
                .tabItem {
                    Label("Bag", systemImage: "bag")
                }
                .tag(BigForeTab.bag)

            SavedCoursesView()
                .tabItem {
                    Label("Saved", systemImage: "tray.full")
                }
                .tag(BigForeTab.saved)
        }
        .preferredColorScheme(prefersDarkMode ? .dark : .light)
    }
}

private enum BigForeTab: Hashable {
    case play
    case find
    case rounds
    case bag
    case saved
}

#Preview {
    ContentView()
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
