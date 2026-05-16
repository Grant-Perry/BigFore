import SwiftData
import SwiftUI

struct PlayHomeView: View {
    let openCourseSearch: () -> Void
    let openSavedCourses: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    @Query(sort: \GolfCourse.courseName) private var savedCourses: [GolfCourse]
    @AppStorage("playHome.prefersDarkMode") private var prefersDarkMode = false
    @State private var viewModel = PlayHomeViewModel()
    @State private var weatherViewModel = WeatherViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BigForeDesign.Spacing.large) {
                    if let activeRound = viewModel.activeRound(from: rounds) {
                        PlayActiveRoundCard(
                            round: activeRound,
                            viewModel: viewModel,
                            weatherSummary: weatherViewModel.summary(for: activeRound),
                            weatherErrorText: weatherViewModel.errorText(for: activeRound)
                        )
                        .task(id: activeRound.id) {
                            await weatherViewModel.loadWeather(for: activeRound, modelContext: modelContext)
                        }
                    } else {
                        PlayEmptyStateCard(
                            hasSavedCourses: !savedCourses.isEmpty,
                            openCourseSearch: openCourseSearch,
                            openSavedCourses: openSavedCourses
                        )
                    }

                    if !savedCourses.isEmpty {
                        PlaySavedCoursesSection(
                            courses: viewModel.savedCourseHighlights(from: savedCourses),
                            viewModel: viewModel,
                            openSavedCourses: openSavedCourses
                        )
                    }

                    if let completedRound = viewModel.recentCompletedRound(from: rounds) {
                        PlayRecentRoundSection(round: completedRound, viewModel: viewModel)
                    }
                }
                .padding(BigForeDesign.Spacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                Text(currentAppVersion)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BigForeDesign.Spacing.xSmall)
                    .background(.clear)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    prefersDarkMode.toggle()
                } label: {
                    Label(prefersDarkMode ? "Use light mode" : "Use dark mode", systemImage: prefersDarkMode ? "sun.max.fill" : "moon.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Circle())
                .padding(.top, BigForeDesign.Spacing.small)
                .padding(.trailing, BigForeDesign.Spacing.large)
            }
            .onAppear {
                viewModel.requestLocationAccess()
            }
        }
    }
}

#Preview {
    PlayHomeView(openCourseSearch: {}, openSavedCourses: {})
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
