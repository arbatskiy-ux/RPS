import MultipeerConnectivity
import Combine

/// The role a device plays in the session.
enum PeerRole: String, Codable {
    case host
    case guest
}

/// Connection lifecycle events emitted to subscribers.
enum ConnectionEvent {
    case peerConnected(MCPeerID)
    case peerDisconnected(MCPeerID)
    case peerConnecting(MCPeerID)
}

/// Wraps MCSession, MCNearbyServiceAdvertiser, and MCNearbyServiceBrowser.
/// Auto-connect: both devices advertise and browse simultaneously.
/// Host/guest role is decided automatically: device with lexicographically smaller
/// device name sends the invite (becomes GUEST); the other accepts (becomes HOST).
final class MultipeerSession: NSObject, ObservableObject {

    private static let serviceType = "rps-game"

    let localPeerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var role: PeerRole?
    @Published private(set) var isConnected: Bool = false

    /// Maps MCPeerID → player's custom display name (from discoveryInfo).
    @Published private(set) var peerDisplayNames: [MCPeerID: String] = [:]

    /// The local player's custom name (set when starting auto-connect).
    private(set) var localPlayerName: String = ""

    /// Emits decoded GameMessages received from remote peers.
    let receivedMessage = PassthroughSubject<GameMessage, Never>()

    /// Emits connection lifecycle events.
    let connectionEvent = PassthroughSubject<ConnectionEvent, Never>()

    init(displayName: String) {
        self.localPeerID = MCPeerID(displayName: displayName)
        self.session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    var isHost: Bool { role == .host }

    // MARK: - Auto Connect

    /// Both advertise and browse simultaneously. Host/guest is decided automatically
    /// by comparing device names — the smaller name sends the invite (GUEST),
    /// the larger name accepts (HOST).
    func startAutoConnect(playerName: String) {
        stopAll()
        role = nil
        localPlayerName = playerName

        advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: ["playerName": playerName],
            serviceType: Self.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: localPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    // MARK: - Connection management

    func disconnect() {
        session.disconnect()
        stopAll()
        connectedPeers = []
        isConnected = false
        role = nil
        peerDisplayNames = [:]
        localPlayerName = ""
    }

    private func stopAll() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    /// Stop discovery once connected to save resources.
    private func stopDiscovery() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
    }

    // MARK: - Sending

    func send(message: GameMessage) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    func send(message: GameMessage, to peer: MCPeerID) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.connectedPeers = session.connectedPeers
            self.isConnected = !session.connectedPeers.isEmpty

            switch state {
            case .connected:
                self.stopDiscovery()
                self.connectionEvent.send(.peerConnected(peerID))
            case .notConnected:
                self.peerDisplayNames.removeValue(forKey: peerID)
                self.connectionEvent.send(.peerDisconnected(peerID))
            case .connecting:
                self.connectionEvent.send(.peerConnecting(peerID))
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(GameMessage.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.receivedMessage.send(message)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // The device that receives the invite becomes HOST
        DispatchQueue.main.async { [weak self] in
            self?.role = .host
        }
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        // Store peer's custom player name from discovery info
        if let playerName = info?["playerName"] {
            DispatchQueue.main.async { [weak self] in
                self?.peerDisplayNames[peerID] = playerName
            }
        }

        // Auto host/guest negotiation via device name comparison.
        // The device with the smaller name sends the invite → GUEST.
        // The device with the larger name waits → HOST (accepts invite).
        // When names are equal, fall back to hash comparison to break the tie.
        let shouldInvite: Bool
        if localPeerID.displayName == peerID.displayName {
            shouldInvite = localPeerID.hash < peerID.hash
        } else {
            shouldInvite = localPeerID.displayName < peerID.displayName
        }

        if shouldInvite {
            DispatchQueue.main.async { [weak self] in
                self?.role = .guest
            }
            // Small delay to let both devices finish discovery before connecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, let browser = self.browser else { return }
                browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
            }
        }
        // else: wait for the other device to invite us
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.peerDisplayNames.removeValue(forKey: peerID)
        }
    }
}
