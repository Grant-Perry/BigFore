import SwiftData
import SwiftUI

struct CourseSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("golfCourseAPIKey") private var apiKey = GolfCourseAPIConfiguration.defaultAPIKey
    @State private var courseSearchViewModel = CourseSearchViewModel(apiKey: GolfCourseAPIConfiguration.defaultAPIKey)
    @State private var isClearRecentsConfirmationPresented = false
    @State private var isRecentsExpanded = false

    var body: some View {
        NavigationStack {
            List {
                searchSection
                nearbySection
                resultsSection

                if courseSearchViewModel.isLoadingCourse {
                    Section {
                        ProgressView("Loading course")
                    }
                }

                if let selectedCourse = courseSearchViewModel.selectedCourse {
                    CourseDetailSection(
                        course: selectedCourse,
                        selectedTeeID: courseSearchViewModel.selectedTeeID,
                        geometryNotice: courseSearchViewModel.courseGeometryNotice,
                        selectTee: courseSearchViewModel.selectTee(id:)
                    ) {
                        courseSearchViewModel.save(course: selectedCourse, modelContext: modelContext)
                    }
                }

                recentsSection
            }
            .navigationTitle("Find Courses")
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                courseSearchViewModel.apiKey = apiKey
            }
            .onDisappear {
                courseSearchViewModel.locationService.stopLocationUpdates()
            }
            .confirmationDialog(
                "Clear all recent courses?",
                isPresented: $isClearRecentsConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Clear Recents", role: .destructive) {
                    courseSearchViewModel.clearRecents()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every course from Recents.")
            }
        }
    }

    private var searchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                Text("Search by course name, club, or city.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: BigForeDesign.Spacing.medium) {
                    TextField("Course or city", text: $courseSearchViewModel.query)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit(performSearch)

                    Button {
                        performSearch()
                    } label: {
                        if courseSearchViewModel.isSearching {
                            ProgressView()
                        } else {
                            Text("Go")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForePrimary)
                    .disabled(!courseSearchViewModel.hasSearchQuery || courseSearchViewModel.isSearching)
                    .accessibilityLabel(courseSearchViewModel.isSearching ? "Searching courses" : "Search")
                }

                TextField("City or ZIP (optional)", text: $courseSearchViewModel.nearbyCityOrZIP)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Text("Leave blank to anchor on your GPS. When filled, Find closest centers on that place and uses the same mile radius (starts at 10 mi).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                HStack(alignment: .center, spacing: BigForeDesign.Spacing.medium) {
                    Button {
                        isRecentsExpanded = false
                        Task { await courseSearchViewModel.findClosestCourses() }
                    } label: {
                        if courseSearchViewModel.isFindingClosest {
                            ProgressView()
                        } else {
                            Label("Find closest", systemImage: "location.circle.fill")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(BigForePillButtonStyle.bigForePrimary)
                    .disabled(courseSearchViewModel.isFindingClosest || courseSearchViewModel.isSearching)

                    Spacer(minLength: 0)
                }

                if courseSearchViewModel.isNearbySessionActive {
                    VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                        Text("Within \(Int(courseSearchViewModel.nearbyRadiusMiles)) mi")
                            .font(.subheadline.weight(.semibold))

                        Slider(
                            value: $courseSearchViewModel.nearbyRadiusMiles,
                            in: CourseSearchViewModel.nearbyRadiusSliderClosedRange,
                            step: CourseSearchViewModel.nearbyRadiusSliderStep,
                            label: {
                                Text("Search radius in miles")
                            },
                            onEditingChanged: { isEditing in
                                if !isEditing {
                                    Task { await courseSearchViewModel.refreshNearbyRadiusAfterSliderReleased() }
                                }
                            }
                        )
                        .labelsHidden()
                        .disabled(courseSearchViewModel.isFindingClosest || courseSearchViewModel.isSearching || courseSearchViewModel.isRefreshingNearbyForRadius)

                        if courseSearchViewModel.isRefreshingNearbyForRadius {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text("Release the slider to search again at the new distance (no search while you drag).")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text("Find closest uses your GPS or an optional city/ZIP center and the mile radius to search Apple Maps for golf POIs, sorted by straight-line distance. The course database has no lat/lon search, so tapping a pin matches it by name and coordinates.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let errorMessage = courseSearchViewModel.errorMessage {
                    CourseSearchMessageRow(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tint: BigForeDesign.Palette.destructive)
                } else if let statusMessage = courseSearchViewModel.statusMessage {
                    CourseSearchMessageRow(message: statusMessage, systemImage: "checkmark.circle.fill", tint: BigForeDesign.Palette.primaryAction)
                }
            }
            .padding(.vertical, BigForeDesign.Spacing.xSmall)
        }
    }

    @ViewBuilder
    private var nearbySection: some View {
        if courseSearchViewModel.isFindingClosest || !courseSearchViewModel.nearbyMapKitRows.isEmpty || courseSearchViewModel.isNearbySessionActive {
            Section {
                if courseSearchViewModel.isFindingClosest {
                    ProgressView("Finding nearby courses")
                } else if courseSearchViewModel.nearbyMapKitRows.isEmpty {
                    ContentUnavailableView(
                        "No courses in range",
                        systemImage: "location.slash",
                        description: Text("Move the distance slider up, adjust city or ZIP, or tap Find closest again.")
                    )
                } else {
                    ForEach(courseSearchViewModel.nearbyMapKitRows) { row in
                        Button {
                            Task {
                                await courseSearchViewModel.selectNearbyMapRow(row)
                                await courseSearchViewModel.ensureOpenStreetMapGeometryIfNeeded(modelContext: modelContext)
                            }
                        } label: {
                            CourseDiscoveryCard(
                                title: row.title,
                                subtitle: row.subtitle ?? "Apple Maps golf POI",
                                detail: "About \(row.distanceCaption) away · opens matched course in the database.",
                                badges: ["Map"],
                                systemImage: "location.fill",
                                accentColor: BigForeDesign.Palette.secondaryAction,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                CourseSearchSectionHeader(
                    title: "Near you",
                    detail: courseSearchViewModel.nearbyMapKitRows.isEmpty ? nil : "\(courseSearchViewModel.nearbyMapKitRows.count)"
                )
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if courseSearchViewModel.isSearching || courseSearchViewModel.hasSearchQuery || !courseSearchViewModel.results.isEmpty {
            Section {
                if courseSearchViewModel.isSearching {
                    ProgressView("Searching courses")
                } else if courseSearchViewModel.results.isEmpty {
                    ContentUnavailableView(
                        "No Courses Found",
                        systemImage: "magnifyingglass",
                        description: Text("Try a nearby city, club name, or shorter course name.")
                    )
                } else {
                    ForEach(courseSearchViewModel.results) { course in
                        Button {
                            Task { await loadCourseAndGeometry(id: course.id) }
                        } label: {
                            CourseDiscoveryCard(
                                title: course.displayName,
                                subtitle: course.location.displayText ?? "No address",
                                detail: "View tees, save the course, or start a round.",
                                badges: course.allTees.isEmpty ? [] : ["\(course.allTees.count) tees"],
                                systemImage: "mappin.and.ellipse",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                CourseSearchSectionHeader(title: "Results", detail: courseSearchViewModel.results.isEmpty ? nil : "\(courseSearchViewModel.results.count)")
            }
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        if !courseSearchViewModel.recents.isEmpty {
            Section {
                if isRecentsExpanded {
                    ForEach(courseSearchViewModel.recents) { recent in
                        Button {
                            Task { await loadCourseAndGeometry(id: recent.id) }
                        } label: {
                            CourseDiscoveryCard(
                                title: recent.displayName,
                                subtitle: recent.locationText,
                                detail: "Tap to inspect tees and start options.",
                                badges: ["Recent"],
                                systemImage: "clock.fill",
                                accentColor: BigForeDesign.Palette.secondaryAction,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                courseSearchViewModel.deleteRecent(id: recent.id)
                            }
                        }
                    }
                } else {
                    Button {
                        withAnimation(.snappy) {
                            isRecentsExpanded = true
                        }
                    } label: {
                        Label("\(courseSearchViewModel.recents.count) recent \(courseSearchViewModel.recents.count == 1 ? "course" : "courses") hidden", systemImage: "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HStack(spacing: BigForeDesign.Spacing.medium) {
                    CourseSearchSectionHeader(title: "Recents", detail: "\(courseSearchViewModel.recents.count)")
                    Spacer()
                    Button(isRecentsExpanded ? "Hide" : "Show") {
                        withAnimation(.snappy) {
                            isRecentsExpanded.toggle()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)

                    if isRecentsExpanded {
                        Button("Clear") {
                            isClearRecentsConfirmationPresented = true
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            }
        }
    }

    private func performSearch() {
        isRecentsExpanded = false
        Task { await courseSearchViewModel.search() }
    }

    private func loadCourseAndGeometry(id: Int) async {
        await courseSearchViewModel.loadCourse(id: id)
        await courseSearchViewModel.ensureOpenStreetMapGeometryIfNeeded(modelContext: modelContext)
    }
}

private struct CourseSearchMessageRow: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(tint)
            .lineLimit(2)
            .labelStyle(.titleAndIcon)
    }
}

private struct CourseSearchSectionHeader: View {
    let title: String
    let detail: String?

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Text(title)
            if let detail {
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, BigForeDesign.Spacing.small)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
        }
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
                .buttonStyle(BigForePillButtonStyle.bigForePrimary)
                .tint(.green)
            } else {
                Button("Start Round", systemImage: "figure.golf") {}
                    .frame(maxWidth: .infinity)
                    .buttonStyle(BigForePillButtonStyle.bigForePrimary)
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
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, CourseMapAreaFeature.self, GolfRound.self, RoundPlayer.self, HoleScore.self, PlayerProfile.self, GolfClub.self, ShotRecord.self, RoundWeatherSnapshot.self], inMemory: true)
}
