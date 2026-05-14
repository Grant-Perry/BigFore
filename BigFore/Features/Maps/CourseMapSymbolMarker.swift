import SwiftUI

struct CourseMapSymbolMarker: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, tint)
            .shadow(radius: 2)
            .accessibilityHidden(true)
    }
}
