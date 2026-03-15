import SwiftUI

struct PeerListView: View {
    @ObservedObject var session: MultipeerSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Players (\(session.connectedPeers.count + 1))")
                .font(.headline)

            // Local player
            HStack {
                Image(systemName: session.isHost ? "crown.fill" : "person.fill")
                    .foregroundStyle(session.isHost ? .orange : .blue)
                Text(session.localPeerID.displayName)
                Text("(You)")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 4)

            // Connected peers
            if session.connectedPeers.isEmpty && session.role != nil {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for other players...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(session.connectedPeers, id: \.displayName) { peer in
                    HStack {
                        Image(systemName: session.isHost ? "person.fill" : "crown.fill")
                            .foregroundStyle(session.isHost ? .blue : .orange)
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
