import SwiftData
import SwiftUI

struct PlayHomeView: View {
    let openCourseSearch: () -> Void
    let openSavedCourses: () -> Void

    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    @Query(sort: \GolfCourse.courseName) private var savedCourses: [GolfCourse]
    @State private var viewModel = PlayHomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BigForeDesign.Spacing.large) {
                    if let activeRound = viewModel.activeRound(from: rounds) {
                        PlayActiveRoundCard(round: activeRound, viewModel: viewModel)
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
            .navigationTitle("Play")
        }
    }
}

#Preview {
    PlayHomeView(openCourseSearch: {}, openSavedCourses: {})
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self], inMemory: true)
}
