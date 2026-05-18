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
            Tab("Play", systemImage: "figure.golf", value: BigForeTab.play) {
                PlayHomeView(
                    openCourseSearch: { selectedTab = .find },
                    openSavedCourses: { selectedTab = .saved },
                    openRounds: { selectedTab = .rounds },
                    openBag: { selectedTab = .bag }
                )
            }

            Tab("Find", systemImage: "magnifyingglass", value: BigForeTab.find) {
                CourseSearchView()
            }

            Tab("Rounds", systemImage: "list.clipboard", value: BigForeTab.rounds) {
                RoundsListView()
            }

            Tab("Bag", systemImage: "bag", value: BigForeTab.bag) {
                BagView(onDismiss: { selectedTab = .play })
            }

            Tab("Saved", systemImage: "tray.full", value: BigForeTab.saved) {
                SavedCoursesView()
            }
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
