import SwiftUI
import UIKit

struct ScorecardShareSheet: View {
    let round: GolfRound
    let showsAllPlayers: Bool
    let showsMetrics: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: BigForeDesign.Spacing.large) {
                ScorecardShareSummaryCard(round: round)
                    .padding(.horizontal)

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share Scorecard", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                } else if let errorText {
                    Text(errorText)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                } else {
                    ProgressView("Preparing scorecard...")
                }

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Share Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .task {
                exportURL = ScorecardShareRenderer.render(round: round, showsAllPlayers: showsAllPlayers, showsMetrics: showsMetrics)
                if exportURL == nil {
                    errorText = "Could not prepare the scorecard image."
                }
            }
        }
    }
}

struct ScorecardSharePreview: View {
    let round: GolfRound
    let nine: ScorecardNine
    var showsHeader = true
    var showsLegend = true
    var showsAllPlayers = true
    var showsMetrics = true
    var showsFinalTotal = false
    private let scoring = RoundScoring()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }
            scoreGrid
            if showsLegend {
                scorecardLegend
            }
        }
        .padding(18)
        .background(.white)
        .foregroundStyle(.black)
    }

    private var players: [RoundPlayer] {
        let sortedPlayers = scoring.sortedPlayers(for: round)
        return showsAllPlayers ? sortedPlayers : Array(sortedPlayers.prefix(1))
    }

    private var holes: [Int] {
        nine.holeNumbers
    }

    private var primaryScores: [HoleScore] {
        scoresForNine(players.first.map(scoring.sortedScores(for:)) ?? [])
    }

    var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(round.courseName)
                    .font(.title.bold())
                Text("\(nine.title) · \(headerDetailText)")
                    .font(.subheadline.weight(.semibold))
                Text(weatherText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.vertical, 2)

                Text(players.first?.name ?? "Player")
                    .font(.headline.bold())
                Text(round.clubName)
                Text("\(round.teeName) Tees")
            }
            .font(.caption)

            Spacer()

            Text("BigFore")
                .font(.title2.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var headerDetailText: String {
        "\(parTotalText) · \(round.startedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private var parTotalText: String {
        let parTotal = primaryScores.reduce(0) { $0 + $1.par }
        return parTotal > 0 ? "Par \(parTotal)" : "Par --"
    }

    private var weatherText: String {
        guard let snapshot = round.weatherSnapshots.sorted(by: { $0.observedAt > $1.observedAt }).first else {
            return "Weather: Not captured"
        }

        var parts: [String] = []
        if let conditionText = snapshot.conditionText {
            parts.append(conditionText)
        }
        if let temperatureText = snapshot.temperatureText {
            parts.append(temperatureText)
        }
        if let windSpeed = snapshot.windSpeedMilesPerHour {
            parts.append("Wind \(windSpeed.rounded().formatted(.number.precision(.fractionLength(0)))) mph")
        }

        return parts.isEmpty ? "Weather: Not captured" : "Weather: \(parts.joined(separator: " · "))"
    }

    private var scoreGrid: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            shareNineTitleRow()
            shareRow("Hole", values: holeValues, isHeader: true)
            shareRow("Distance", values: metricValues { $0.yardage.map(String.init) ?? "--" })
            shareRow("Handicap", values: metricValues { $0.handicap.map(String.init) ?? "--" })
            shareRow("Par", values: metricValues { "\($0.par)" })

            ForEach(players) { player in
                let allScores = scoring.sortedScores(for: player)
                let scores = scoresForNine(allScores)
                shareScoreRow(player.name, scores: scores, allScores: allScores)
                if showsMetrics {
                    shareRelativeRow("Round Score", scores: scores)
                    shareRow("Putts", values: metricValues(for: scores) { $0.putts.map(String.init) ?? "--" })
                    shareRow("Tee Result", values: metricValues(for: scores) { $0.teeShotAccuracy?.shortTitle ?? "--" })
                    shareRow("GIR", values: metricValues(for: scores) { $0.girEstimate.map { $0 ? "Y" : "N" } ?? "--" })
                }
            }
        }
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .overlay {
            Rectangle()
                .stroke(.black.opacity(0.18), lineWidth: 1)
        }
    }

    private func shareRow(_ title: String, values: [String], isHeader: Bool = false) -> some View {
        GridRow {
            scoreCell(title, width: 72, isHeader: isHeader)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                scoreCell(value, isHeader: isHeader)
            }
        }
    }

    private func shareNineTitleRow() -> some View {
        GridRow {
            scoreCell("", width: 72, isHeader: true)
            Text(nine.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .kerning(2.0)
                .foregroundStyle(.white)
                .frame(width: CGFloat(holeValues.count) * 32, height: 22)
                .background(Color.black.opacity(0.84))
                .border(.black.opacity(0.12), width: 0.5)
                .gridCellColumns(holeValues.count)
        }
    }

    private func shareScoreRow(_ title: String, scores: [HoleScore], allScores: [HoleScore]) -> some View {
        GridRow {
            scoreCell(title, width: 72, isHeader: true, isPlayerName: true)
            ForEach(Array(scoreValues(for: scores, allScores: allScores).enumerated()), id: \.offset) { _, value in
                scoreCell(value.text, isHeader: value.isTotal, fill: value.fill, isTotal: value.isTotal, isFinalTotal: value.isFinalTotal)
            }
        }
    }

    private func shareRelativeRow(_ title: String, scores: [HoleScore]) -> some View {
        let values = frontBackValues(for: scores) { selectedScores in
            let scored = selectedScores.filter { $0.strokes > 0 }
            guard !scored.isEmpty else {
                return "--"
            }

            let relative = scored.reduce(0) { $0 + $1.strokes - $1.par }
            return scoring.relativeText(relative)
        }

        return shareRow(title, values: values)
    }

    private func scoreCell(_ text: String, width: CGFloat = 32, isHeader: Bool = false, fill: Color? = nil, isTotal: Bool = false, isFinalTotal: Bool = false, isEmphasized: Bool = false, isPlayerName: Bool = false) -> some View {
        Text(text)
            .font(cellFont(isHeader: isHeader, isTotal: isTotal, isFinalTotal: isFinalTotal, isEmphasized: isEmphasized))
            .italic(isFinalTotal)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: width, height: 22)
            .foregroundStyle(textColor(isHeader: isHeader, fill: fill, isTotal: isTotal, isPlayerName: isPlayerName))
            .background(cellBackground(isHeader: isHeader, fill: fill, isTotal: isTotal, isPlayerName: isPlayerName))
            .border(.black.opacity(0.12), width: 0.5)
    }

    private func cellFont(isHeader: Bool, isTotal: Bool, isFinalTotal: Bool, isEmphasized: Bool) -> Font {
        if isFinalTotal {
            return .system(size: 11, weight: .bold, design: .rounded)
        }

        if isTotal {
            return .system(size: 11, weight: .black, design: .rounded)
        }

        if isHeader || isEmphasized {
            return .system(size: 9, weight: .bold, design: .rounded)
        }

        return .system(size: 9, weight: .medium, design: .rounded)
    }

    private func textColor(isHeader: Bool, fill: Color?, isTotal: Bool, isPlayerName: Bool) -> Color {
        if isTotal || isPlayerName {
            return .black
        }

        if fill != nil || isHeader {
            return .white
        }

        return .black
    }

    private func cellBackground(isHeader: Bool, fill: Color?, isTotal: Bool, isPlayerName: Bool) -> Color {
        if isTotal || isPlayerName {
            return Color.gpYellow
        }

        if let fill {
            return fill
        }

        return isHeader ? Color.black.opacity(0.84) : Color.white
    }

    var scorecardLegend: some View {
        HStack(spacing: 10) {
            ForEach(ScorecardScoreResult.legendItems) { item in
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                    Text(item.title)
                }
            }
        }
        .font(.system(size: 8, weight: .medium))
    }

    private func totalText(for title: String, values: [String]) -> String {
        if title == "Hole" {
            return "Total"
        }

        let total = values.compactMap(Int.init).reduce(0, +)
        return total > 0 ? "\(total)" : "--"
    }

    private var holeValues: [String] {
        holes.map(String.init) + [nine.totalTitle] + (showsFinalTotal ? ["TOTAL"] : [])
    }

    private func metricValues(_ transform: (HoleScore) -> String) -> [String] {
        metricValues(for: primaryScores, transform)
    }

    private func metricValues(for scores: [HoleScore], _ transform: (HoleScore) -> String) -> [String] {
        frontBackValues(for: scores, transform: transform) { selectedScores in
            totalText(for: "", values: selectedScores.map(transform))
        }
    }

    private func scoreValues(for scores: [HoleScore], allScores: [HoleScore]) -> [ShareScoreCellValue] {
        let values = frontBackValues(for: scores) { score in
            ShareScoreCellValue(
                text: score.strokes > 0 ? "\(score.strokes)" : "--",
                fill: score.strokes > 0 ? ScorecardScoreResult(relativeToPar: score.strokes - score.par)?.solidColor : nil,
                isTotal: false
            )
        } total: { selectedScores in
            let strokes = selectedScores.reduce(0) { $0 + max($1.strokes, 0) }
            return ShareScoreCellValue(text: strokes > 0 ? "\(strokes)" : "--", fill: nil, isTotal: true)
        }

        guard showsFinalTotal else {
            return values
        }

        let total = allScores.reduce(0) { $0 + max($1.strokes, 0) }
        return values + [ShareScoreCellValue(text: total > 0 ? "\(total)" : "--", fill: Color.gpPostTop, isTotal: true, isFinalTotal: true)]
    }

    private func frontBackValues<T>(for values: [T], transform: (T) -> String, total: ([T]) -> String) -> [String] {
        values.map(transform) + [total(values)]
    }

    private func frontBackValues<T>(for values: [T], transform: (T) -> ShareScoreCellValue, total: ([T]) -> ShareScoreCellValue) -> [ShareScoreCellValue] {
        values.map(transform) + [total(values)]
    }

    private func frontBackValues<T>(for values: [T], total: ([T]) -> String) -> [String] {
        frontBackValues(for: values, transform: { _ in "" }, total: total)
    }

    private func scoresForNine(_ scores: [HoleScore]) -> [HoleScore] {
        scores.filter { holes.contains($0.holeNumber) }
    }
}

struct FullScorecardShareView: View {
    let round: GolfRound
    var showsAllPlayers = true
    var showsMetrics = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                FullScorecardHeader(round: round)

                HStack(alignment: .top, spacing: 20) {
                    ScorecardSharePreview(round: round, nine: .front, showsHeader: false, showsLegend: false, showsAllPlayers: showsAllPlayers, showsMetrics: showsMetrics)
                    ScorecardSharePreview(round: round, nine: .back, showsHeader: false, showsLegend: false, showsAllPlayers: showsAllPlayers, showsMetrics: showsMetrics, showsFinalTotal: true)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            ScorecardColorKey()
        }
        .padding(18)
        .background(.white)
        .foregroundStyle(.black)
    }
}

private struct FullScorecardHeader: View {
    let round: GolfRound

    private var scoring: RoundScoring { RoundScoring() }

    private var primaryScores: [HoleScore] {
        round.players.sorted { $0.displayOrder < $1.displayOrder }.first.map(scoring.sortedScores(for:)) ?? []
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(round.courseName)
                    .font(.title.bold())
                Text("\(parTotalText) · \(round.startedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline.weight(.semibold))
                Text(weatherText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(round.players.sorted { $0.displayOrder < $1.displayOrder }.first?.name ?? "Player")
                    .font(.headline.bold())
            }

            Spacer()

            ScorecardScoreSummaryCard(
                front: scoreStrokesAndPar(for: 1...9)?.strokes,
                back: scoreStrokesAndPar(for: 10...18)?.strokes,
                total: scoreStrokesAndPar(for: 1...18)
            )
        }
    }

    private var parTotalText: String {
        let parTotal = primaryScores.reduce(0) { $0 + $1.par }
        return parTotal > 0 ? "Par \(parTotal)" : "Par --"
    }

    private var weatherText: String {
        guard let snapshot = round.weatherSnapshots.sorted(by: { $0.observedAt > $1.observedAt }).first else {
            return "Weather: Not captured"
        }

        var parts: [String] = []
        if let conditionText = snapshot.conditionText {
            parts.append(conditionText)
        }
        if let temperatureText = snapshot.temperatureText {
            parts.append(temperatureText)
        }
        if let windSpeed = snapshot.windSpeedMilesPerHour {
            parts.append("Wind \(windSpeed.rounded().formatted(.number.precision(.fractionLength(0)))) mph")
        }

        return parts.isEmpty ? "Weather: Not captured" : "Weather: \(parts.joined(separator: " · "))"
    }

    private func scoreStrokesAndPar(for holes: ClosedRange<Int>) -> (strokes: Int, par: Int)? {
        let selectedScores = primaryScores.filter { holes.contains($0.holeNumber) && $0.strokes > 0 }
        guard !selectedScores.isEmpty else {
            return nil
        }

        let strokes = selectedScores.reduce(0) { $0 + $1.strokes }
        let par = selectedScores.reduce(0) { $0 + $1.par }
        return (strokes, par)
    }
}

private struct ScorecardScoreSummaryCard: View {
    let front: Int?
    let back: Int?
    let total: (strokes: Int, par: Int)?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                scoreLine(title: "Front", value: front)
                scoreLine(title: "Back", value: back)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)

            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .font(.headline.bold())
                    .foregroundStyle(.black)
                Spacer(minLength: 4)
                totalStrokesRelativeLabel
                    .frame(minWidth: 0, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.gpYellow)
        }
        .frame(width: 170)
        .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var totalStrokesRelativeLabel: some View {
        if let total {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(total.strokes)")
                    .font(.title3.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("/")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(relativeToParText(strokes: total.strokes, par: total.par))
                    .font(.title3.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(relativeToParColor(strokes: total.strokes, par: total.par))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        } else {
            Text("--")
                .font(.title3.weight(.black))
                .monospacedDigit()
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func relativeToParText(strokes: Int, par: Int) -> String {
        let diff = strokes - par
        if diff == 0 {
            return "E"
        }
        if diff > 0 {
            return "+\(diff)"
        }
        return "\(diff)"
    }

    private func relativeToParColor(strokes: Int, par: Int) -> Color {
        let diff = strokes - par
        if diff < 0 {
            return .blue
        }
        if diff > 0 {
            return .gpRedPink
        }
        return .black
    }

    private func scoreLine(title: String, value: Int?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(scoreText(value))
                .font(.headline.weight(.bold))
                .monospacedDigit()
        }
    }

    private func scoreText(_ value: Int?) -> String {
        value.map(String.init) ?? "--"
    }
}

private struct ScorecardColorKey: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(ScorecardScoreResult.legendItems) { item in
                HStack(spacing: 5) {
                    Rectangle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)
                    Text(item.title)
                }
            }
        }
        .font(.caption.weight(.medium))
    }
}

@MainActor
private enum ScorecardShareRenderer {
    static func render(round: GolfRound, showsAllPlayers: Bool, showsMetrics: Bool) -> URL? {
        let content = FullScorecardShareView(round: round, showsAllPlayers: showsAllPlayers, showsMetrics: showsMetrics)
            .frame(width: 1_850)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3

        guard let image = renderer.uiImage else {
            return nil
        }

        let filename = "BigFore-\(round.courseName.replacingOccurrences(of: " ", with: "-"))-\(round.id.uuidString.prefix(8)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let pageBounds = CGRect(origin: .zero, size: image.size)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        do {
            let data = pdfRenderer.pdfData { context in
                context.beginPage()
                image.draw(in: pageBounds)
            }
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private struct ShareScoreCellValue {
    let text: String
    let fill: Color?
    let isTotal: Bool
    var isFinalTotal = false
}

private struct ScorecardShareSummaryCard: View {
    let round: GolfRound

    private var primaryScores: [HoleScore] {
        round.players.sorted { $0.displayOrder < $1.displayOrder }.first?.scores.sorted { $0.holeNumber < $1.holeNumber } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.courseName)
                        .font(.title2.bold())
                    Text("\(parTotalText) · \(round.startedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(weatherText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("PDF")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, BigForeDesign.Spacing.medium)
                    .padding(.vertical, BigForeDesign.Spacing.small)
                    .background(BigForeDesign.Palette.primaryAction, in: Capsule())
            }

            Text("The shared scorecard is generated as a landscape PDF so the full 18-hole table is readable when opened or sent.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BigForeDesign.Spacing.large)
        .background(BigForeDesign.Gradients.cardFill, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
    }

    private var parTotalText: String {
        let parTotal = primaryScores.reduce(0) { $0 + $1.par }
        return parTotal > 0 ? "Par \(parTotal)" : "Par --"
    }

    private var weatherText: String {
        guard let snapshot = round.weatherSnapshots.sorted(by: { $0.observedAt > $1.observedAt }).first else {
            return "Weather: Not captured"
        }

        var parts: [String] = []
        if let conditionText = snapshot.conditionText {
            parts.append(conditionText)
        }
        if let temperatureText = snapshot.temperatureText {
            parts.append(temperatureText)
        }
        if let windSpeed = snapshot.windSpeedMilesPerHour {
            parts.append("Wind \(windSpeed.rounded().formatted(.number.precision(.fractionLength(0)))) mph")
        }

        return parts.isEmpty ? "Weather: Not captured" : "Weather: \(parts.joined(separator: " · "))"
    }
}

private struct ScorecardLegendItem: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
}

private extension ScorecardScoreResult {
    var solidColor: Color {
        tint
    }

    static var legendItems: [ScorecardLegendItem] {
        [
            ScorecardLegendItem(title: "Eagle+", color: ScorecardScoreResult(relativeToPar: -2)!.solidColor),
            ScorecardLegendItem(title: "Birdie", color: ScorecardScoreResult(relativeToPar: -1)!.solidColor),
            ScorecardLegendItem(title: "Par", color: ScorecardScoreResult(relativeToPar: 0)!.solidColor),
            ScorecardLegendItem(title: "Bogey", color: ScorecardScoreResult(relativeToPar: 1)!.solidColor),
            ScorecardLegendItem(title: "Double", color: ScorecardScoreResult(relativeToPar: 2)!.solidColor),
            ScorecardLegendItem(title: "Triple", color: ScorecardScoreResult(relativeToPar: 3)!.solidColor)
        ]
    }
}
