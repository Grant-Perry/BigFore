import CoreLocation
import Foundation
import Observation
import SwiftData
import SwiftUI

struct SavedCoursesView: View {
    @Query(sort: \GolfCourse.courseName) private var courses: [GolfCourse]

    var body: some View {
        NavigationStack {
            List {
                if courses.isEmpty {
                    Text("Saved courses will appear here.")
                        .foregroundStyle(.secondary)
                }

                ForEach(courses) { course in
                    NavigationLink {
                        SavedCourseDetailView(course: course)
                    } label: {
                        SavedCourseRow(course: course)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Saved Courses")
            .listStyle(.insetGrouped)
        }
    }
}

private struct SavedCourseRow: View {
    let course: GolfCourse

    var body: some View {
        CourseDiscoveryCard(
            title: course.courseName,
            subtitle: subtitle,
            detail: "Pick a tee, open GPS, or start a round.",
            badges: badges,
            systemImage: "flag.checkered",
            showsChevron: true
        )
    }

    private var subtitle: String {
        if course.clubName == course.courseName {
            return locationText ?? "Saved course"
        }

        if let locationText {
            return "\(course.clubName) · \(locationText)"
        }

        return course.clubName
    }

    private var badges: [String] {
        var badges = ["\(course.tees.count) \(course.tees.count == 1 ? "tee" : "tees")"]
        if course.latitude != nil && course.longitude != nil {
            badges.append("GPS")
        }
        return badges
    }

    private var locationText: String? {
        let parts = [course.city, course.state, course.country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return course.address
        }

        return parts.joined(separator: ", ")
    }
}

struct SavedCourseDetailView: View {
    let course: GolfCourse
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SavedCourseDetailViewModel

    init(course: GolfCourse) {
        self.course = course
        _viewModel = State(initialValue: SavedCourseDetailViewModel(course: course))
    }

    private var sortedTees: [GolfCourseTee] {
        course.tees.sorted { $0.name < $1.name }
    }

    private var selectedTee: GolfCourseTee? {
        sortedTees.first { viewModel.isSelected(tee: $0) }
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            Section("Course") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(course.courseName)
                        .font(.headline)
                    Text(course.clubName)
                        .foregroundStyle(.secondary)
                    Text(viewModel.coordinateSummary(for: course))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.courseGeometryNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let mapPoint = CourseMapPoint(savedCourse: course) {
                    NavigationLink("Open Course Map") {
                        CourseMapView(course: mapPoint)
                    }
                }

                if let selectedTee {
                    NavigationLink {
                        StartRoundView(savedCourse: course, tee: selectedTee)
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

            Section("Course Pin") {
                Text("Correct the course-level GPS point used for saved-course maps and new rounds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Latitude", text: $viewModel.latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Longitude", text: $viewModel.longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                Text(viewModel.locationService.locationStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Request GPS") {
                        viewModel.requestLocationAccess()
                    }
                    Button("Use My Location") {
                        viewModel.useCurrentLocationForPin()
                    }
                    .disabled(viewModel.locationService.currentLocation == nil)
                }
                .buttonStyle(.bordered)
                HStack {
                    Button("Save Course Pin") {
                        viewModel.saveCoursePin(course: course, modelContext: modelContext)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Clear Pin") {
                        viewModel.clearCoursePin(course: course, modelContext: modelContext)
                    }
                    .buttonStyle(.bordered)
                    .disabled(course.latitude == nil && course.longitude == nil)
                }
                if let pinStatusMessage = viewModel.pinStatusMessage {
                    Text(pinStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let pinErrorMessage = viewModel.pinErrorMessage {
                    Text(pinErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Tees") {
                if sortedTees.isEmpty {
                    Text("No tees are saved for this course.")
                        .foregroundStyle(.secondary)
                }

                ForEach(sortedTees) { tee in
                    SavedTeeSelectionRow(
                        tee: tee,
                        isSelected: viewModel.isSelected(tee: tee),
                        select: { viewModel.select(tee: tee) }
                    )
                }
            }
        }
        .navigationTitle(course.courseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
@Observable
private final class SavedCourseDetailViewModel {
    var selectedTeeID: PersistentIdentifier?
    var latitudeText: String
    var longitudeText: String
    var pinStatusMessage: String?
    var pinErrorMessage: String?
    var locationService = LocationService()
    private let geometryStrategy: CourseGeometryStrategy
    private let coordinateEditor: CourseCoordinateEditor

    init(
        course: GolfCourse,
        geometryStrategy: CourseGeometryStrategy = CourseGeometryStrategy(),
        coordinateEditor: CourseCoordinateEditor = CourseCoordinateEditor()
    ) {
        self.geometryStrategy = geometryStrategy
        self.coordinateEditor = coordinateEditor
        latitudeText = Self.coordinateText(for: course.latitude)
        longitudeText = Self.coordinateText(for: course.longitude)
        selectedTeeID = course.tees.sorted { $0.name < $1.name }.first?.persistentModelID
    }

    func select(tee: GolfCourseTee) {
        selectedTeeID = tee.persistentModelID
    }

    func isSelected(tee: GolfCourseTee) -> Bool {
        selectedTeeID == tee.persistentModelID
    }

    var courseGeometryNotice: String {
        geometryStrategy.currentLimitationsNotice
    }

    func coordinateSummary(for course: GolfCourse) -> String {
        guard let latitude = course.latitude, let longitude = course.longitude else {
            return "This saved course does not include course-level coordinates."
        }

        return "Course pin: \(Self.coordinateText(for: latitude)), \(Self.coordinateText(for: longitude))"
    }

    func requestLocationAccess() {
        locationService.requestLocationAccess()
    }

    func useCurrentLocationForPin() {
        pinErrorMessage = nil
        pinStatusMessage = nil

        guard let coordinate = locationService.currentLocation?.coordinate else {
            pinErrorMessage = "Current location is not available yet."
            return
        }

        latitudeText = Self.coordinateText(for: coordinate.latitude)
        longitudeText = Self.coordinateText(for: coordinate.longitude)
        pinStatusMessage = "Loaded your current GPS location into the course pin fields."
    }

    func saveCoursePin(course: GolfCourse, modelContext: ModelContext) {
        pinErrorMessage = nil
        pinStatusMessage = nil

        do {
            try coordinateEditor.save(
                latitudeText: latitudeText,
                longitudeText: longitudeText,
                for: course,
                modelContext: modelContext
            )
            latitudeText = Self.coordinateText(for: course.latitude)
            longitudeText = Self.coordinateText(for: course.longitude)
            pinStatusMessage = "Saved course pin."
        } catch {
            modelContext.rollback()
            pinErrorMessage = error.localizedDescription
        }
    }

    func clearCoursePin(course: GolfCourse, modelContext: ModelContext) {
        pinErrorMessage = nil
        pinStatusMessage = nil

        do {
            try coordinateEditor.clearCoordinates(for: course, modelContext: modelContext)
            latitudeText = ""
            longitudeText = ""
            pinStatusMessage = "Cleared course pin."
        } catch {
            modelContext.rollback()
            pinErrorMessage = "Could not clear course pin: \(error.localizedDescription)"
        }
    }

    private static func coordinateText(for value: Double?) -> String {
        guard let value else {
            return ""
        }

        return String(format: "%.6f", value)
    }
}

private struct SavedTeeSelectionRow: View {
    let tee: GolfCourseTee
    let isSelected: Bool
    let select: () -> Void
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                if let rating = tee.courseRating, let slope = tee.slopeRating {
                    LabeledContent("Rating / Slope", value: "\(rating.formatted()) / \(slope)")
                }

                ForEach(tee.holes.sorted { $0.number < $1.number }) { hole in
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
                    Text("\(tee.name) · \(tee.gender.capitalized)")
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
    SavedCoursesView()
        .modelContainer(for: [GolfCourse.self, GolfCourseTee.self, GolfCourseHole.self, CourseGeometry.self, HoleGeometry.self, CourseMapFeaturePoint.self, GolfRound.self, RoundPlayer.self, HoleScore.self], inMemory: true)
}
