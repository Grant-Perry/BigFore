enum CourseMapSelectionMode: String, CaseIterable, Identifiable {
    case measurementPin
    case teeBox
    case holePin
    case shotStart
    case shotBall
    case moveShotBall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .measurementPin:
            "Measure"
        case .teeBox:
            "Tee"
        case .holePin:
            "Pin"
        case .shotStart:
            "Start"
        case .shotBall:
            "Ball"
        case .moveShotBall:
            "Move Ball"
        }
    }

    var tapInstruction: String {
        switch self {
        case .measurementPin:
            "The next map tap drops the measurement pin."
        case .teeBox:
            "Tap the tee box. It stays saved for this hole."
        case .holePin:
            "Tap the hole/pin. It stays saved for this hole."
        case .shotStart:
            "The next map tap sets or overrides the shot start."
        case .shotBall:
            "The next map tap marks the ball/end location."
        case .moveShotBall:
            "Select a ball marker, then tap its corrected location."
        }
    }
}
