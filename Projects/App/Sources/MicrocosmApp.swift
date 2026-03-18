import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import ComposableArchitecture

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct MicrocosmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

struct AppRootView: View {
    var body: some View {
        RootView(
            store: Store(initialState: RootFeature.State()) {
                RootFeature()
            }
        )
    }
}
