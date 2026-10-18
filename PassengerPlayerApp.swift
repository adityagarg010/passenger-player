import SwiftUI
import UIKit

@main
struct PassengerPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(PlayerModel.shared)
                .environmentObject(LibraryStore.shared)
                .environmentObject(LocalLibrary.shared)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PlayerModel.shared.configureAudioSession()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        // A wired HDMI / USB-C display was plugged in: show the video there.
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            config.delegateClass = ExternalSceneDelegate.self
        }
        return config
    }

    // Lets Car Mode switch the phone to landscape and back.
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}
