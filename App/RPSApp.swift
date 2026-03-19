import SwiftUI
import UIKit

@main
struct RPSApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                // Intercept UIKit shake for Simulator support
                .background(
                    ShakeViewRepresentable(motionManager: appState.motionManager)
                        .frame(width: 0, height: 0)
                )
        }
    }
}

// MARK: - UIKit shake bridge for Simulator

/// Invisible UIView that forwards UIKit motionBegan → MotionManager.
private struct ShakeViewRepresentable: UIViewRepresentable {
    let motionManager: MotionManager

    func makeUIView(context: Context) -> ShakeView {
        let view = ShakeView()
        view.motionManager = motionManager
        return view
    }

    func updateUIView(_ uiView: ShakeView, context: Context) {
        uiView.motionManager = motionManager
    }
}

private class ShakeView: UIView {
    var motionManager: MotionManager?

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        becomeFirstResponder()
    }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            motionManager?.handleUIKitShake()
        }
    }
}
