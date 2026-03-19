import SwiftUI

/// Circular avatar — shows photo if available, otherwise a colored initial.
struct PlayerAvatar: View {
    let name: String
    let imageData: Data?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    colorForName(name)
                    Text(initial)
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }

    private func colorForName(_ name: String) -> Color {
        let palette: [Color] = [.blue, .indigo, .purple, .pink, .orange, .green, .teal]
        let index = abs(name.unicodeScalars.reduce(0) { $0 + Int($1.value) }) % palette.count
        return palette[index]
    }
}
