import SwiftUI

struct ActionButton: View {
    enum Style { case primary, secondary }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .frame(maxWidth: .infinity)
            .padding()
            .background(style == .primary ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(style == .primary ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
