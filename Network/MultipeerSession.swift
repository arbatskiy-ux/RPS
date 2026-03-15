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
/// The device that starts advertising becomes the HOST; the device that browses and joins becomes the GUEST.
final class MultipeerSession: NSObject, ObservableObject {

    private static let serviceType = "peerplay-game"

    let localPeerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var role: PeerRole?
    @Published private(set) var isConnected: Bool = false

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

    // MARK: - Advertising (HOST)

    /// Start advertising this device as a HOST. The first device to advertise owns the session.
    func startHosting() {
        stopAll()
        role = .host
        advertiser = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: ["role": PeerRole.host.rawValue],
            serviceType: Self.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    // MARK: - Browsing (GUEST)

    /// Start browsing for a HOST to join as a GUEST.
    func startBrowsing() {
        stopAll()
        role = .guest
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

    /// Send a message to a specific peer only.
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
        // Auto-accept incoming connections
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        // Only connect to hosts
        guard info?["role"] == PeerRole.host.rawValue else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
