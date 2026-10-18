import UIKit
import AVFoundation

/// Handles a wired external display (USB-C / Lightning HDMI adapter, rear-seat monitor).
/// Shows the shared player full screen, with no phone UI.
final class ExternalSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ExternalPlayerViewController()
        window.isHidden = false
        self.window = window

        Task { @MainActor in PlayerModel.shared.externalDisplayConnected = true }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        Task { @MainActor in PlayerModel.shared.externalDisplayConnected = false }
    }
}

final class ExternalPlayerViewController: UIViewController {
    private let playerLayer = AVPlayerLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        Task { @MainActor in
            self.playerLayer.player = PlayerModel.shared.player
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer.frame = view.bounds
    }
}
