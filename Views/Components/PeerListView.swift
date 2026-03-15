import SwiftUI

struct PeerListView: View {
    @ObservedObject var session: MultipeerSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connected Peers (\(session.connectedPeers.count))")
                .font(.headline)

            if session.connectedPeers.isEmpty {
                Text("No peers connected yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(session.connectedPeers, id: \.displayName) { peer in
                    HStack {
                        Image(systemName: "iphone")
                        Text(peer.displayName)
                        Spacer()
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
