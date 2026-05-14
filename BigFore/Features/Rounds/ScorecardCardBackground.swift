import SwiftUI

extension View {
    func scorecardCardBackground() -> some View {
        background {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel)
                .fill(BigForeDesign.Gradients.cardFill)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel))
    }
}
