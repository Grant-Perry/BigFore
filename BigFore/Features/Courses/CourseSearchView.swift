import SwiftData
import SwiftUI

struct CourseSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("golfCourseAPIKey") private var apiKey = GolfCourseAPIConfiguration.defaultAPIKey
    @State private var viewModel = CourseSearchViewModel(apiKey: GolfCourseAPIConfiguration.defaultAPIKey)
    @State private var isClearRecentsConfirmationPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section("Search") {
                    TextField("Search courses", text: $viewModel.query)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await viewModel.search() }
                        }

                    if viewModel.hasSearchQuery {
                        Button(viewModel.isSearching ? "Searching..." : "Go") {
                            Task { await viewModel.search() }
                        }
                        .disabled(viewModel.isSearching)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let statusMessage = viewModel.statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if !viewModel.recents.isEmpty {
                    Section {
                        ForEach(viewModel.recents) { recent in
                            Button {
                                Task { await loadCourseAndGeometry(id: recent.id) }
                            } label: {
                                CourseDiscoveryCard(
                                    title: recent.displayName,
                                    subtitle: recent.locationText,
                                    detail: "Tap to inspect tees and start options.",
                                    badges: ["Recent"],
                                    systemImage: "clock.fill",
                                    accentColor: BigForeDesign.Palette.secondaryAction
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteRecent(id: recent.id)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Recents")
                            Spacer()
                            Button("Clear") {
                                isClearRecentsConfirmationPresented = true
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    }
                }

                Section("Results") {
                    if viewModel.results.isEmpty && !viewModel.isSearching {
                        Text("Search for a course to inspect tee options.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.results) { course in
                        Button {
                            Task { await loadCourseAndGeometry(id: course.id) }
                        } label: {
                            CourseDiscoveryCard(
                                title: course.displayName,
                                subtitle: course.location.displayText ?? "No address",
                                detail: "View tee boxes, save the course, or start a round.",
                                badges: course.allTees.isEmpty ? [] : ["\(course.allTees.count) tees"],
                                systemImage: "mappin.and.ellipse"
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }

                if viewModel.isLoadingCourse {
                    Section {
                        ProgressView("Loading course")
                    }
                }

                if let selectedCourse = viewModel.selectedCourse {
                    CourseDetailSection(
                        course: selectedCourse,
                        selectedTeeID: viewModel.selectedTeeID,
                        geometryNotice: viewModel.courseGeometryNotice,
                        selectTee: viewModel.selectTee(id:)
                    ) {
                        viewModel.save(course: selectedCourse, modelContext: modelContext)
                    }
                }
            }
            .navigationTitle("Find Courses")
            .listStyle(.insetGrouped)
            .onAppear {
                viewModel.apiKey = apiKey
            }
            .confirmationDialog(
                "Clear all recent courses?",
                isPresented: $isClearRecentsConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Clear Recents", role: .destructive) {
                    viewModel.clearRecents()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every course from Recents.")
            }
        }
    }

    private func loadCourseAndGeometry(id: Int) async {
        await viewModel.loadCourse(id: id)
        await viewModel.ensureOpenStreetMapGeometryIfNeeded(modelContext: modelContext)
    }
}

struct CourseDetailSection: View {
    let course: GolfCourseAPICourse
    let selectedTeeID: String?
    let geometryNotice: String
    let selectTee: (String) -> Void
    let save: () -> Void

    private var selectedTee: GolfCourseAPITeeBox? {
        course.allTees.first { $0.id == selectedTeeID }
    }

    var body: some View {
        Section("Selected Course") {
            VStack(alignment: .leading, spacing: 6) {
                Text(course.displayName)
                    .font(.headline)
                if let address = course.location.address {
                    Text(address)
                }
                if let latitude = course.location.latitude, let longitude = course.location.longitude {
                    Text("Course location: \(latitude), \(longitude)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No course-level coordinates returned.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(geometryNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Save Course") {
                save()
            }

            if let mapPoint = CourseMapPoint(apiCourse: course) {
                NavigationLink("Open Course Map") {
                    CourseMapView(course: mapPoint)
                }
            }

            if let selectedTee {
                NavigationLink {
                    StartRoundView(course: course, tee: selectedTee)
                } label: {
                    Label("Start Round", systemImage: "figure.golf")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button("Start Round", systemImage: "figure.golf") {}
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(true)

                Text("Select a tee before starting a round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Tees") {
            if course.allTees.isEmpty {
                Text("No tees were returned for this course.")
                    .foregroundStyle(.secondary)
            }

            ForEach(course.allTees) { tee in
                APITeeSelectionRow(
                    tee: tee,
                    isSelected: tee.id == selectedTeeID,
                    select: { selectTee(tee.id) }
                )
            }
        }
    }
}

private struct APITeeSelectionRow: View {
    let tee: GolfCourseAPITeeBox
    let isSelected: Bool
    let select: () -> Void
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let rating = tee.courseRating, let slope = tee.slopeRating {
                    LabeledContent("Rating / Slope", value: "\(rating.formatted()) / \(slope)")
                }

                ForEach(tee.holesWithNumbers) { hole in
                    HStack {
                        Text("Hole \(hole.number)")
                        Spacer()
                        Text("Par \(hole.par ?? 0)")
                        Text("\(hole.yardage ?? 0) yds")
                        Text("HCP \(hole.handicap ?? 0)")
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 12) {
                Button(action: select) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(isSelected ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Selected tee" : "Select tee")

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(tee.teeName) · \(tee.gender.capitalized)")
                        .font(.headline)
                    Text("\(tee.totalYards ?? 0) yds · Par \(tee.parTotal ?? 0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    CourseSearchView()
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self], inMemory: true)
}
