import SwiftUI

struct PlayerNameField: View {
    @Binding var name: String

    var body: some View {
        HStack {
            Image(systemName: "person.circle")
                .foregroundStyle(.secondary)
            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
