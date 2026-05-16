import SwiftUI

extension View {
    /// Canvas behind scorecard cards — slightly lifted from plain grouped so panels read more clearly.
    func scorecardScreenBackground(colorScheme: ColorScheme) -> some View {
        background {
            ZStack {
                Color(.systemGroupedBackground)
                Color.secondary.opacity(colorScheme == .dark ? 0.08 : 0.045)
            }
            .ignoresSafeArea()
        }
    }

    func scorecardCardBackground() -> some View {
        background {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel)
                        .fill(Color(.systemBackground).opacity(0.32))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel))
    }
}
