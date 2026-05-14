extension CourseMapHoleMarker.Kind {
    var assetName: String {
        switch self {
        case .tee:
            "bluePin"
        case .pin:
            "greenPin"
        }
    }
}
