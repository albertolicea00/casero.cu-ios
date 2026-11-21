import SwiftUI

/// Full-width filled button shared by the SMS report and guest lookup forms.
struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(
                Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.55),
                in: RoundedRectangle(cornerRadius: 14)
            )
    }
}
