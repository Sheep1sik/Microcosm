import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import ComposableArchitecture
import FeatureRoot

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        cleanupStaleSessionIfFirstLaunch()
        return true
    }

    /// iOS Keychain 은 앱 삭제 후에도 유지돼 Firebase / Google 세션이 재설치 시 복구된다.
    /// UserDefaults 는 앱 sandbox 에 속해 재설치 시 초기화되므로 첫 실행 플래그로 감지해
    /// 잔여 세션을 강제 정리한다. Auth.signOut 은 동기 API 라 bootstrap 단계에서 안전하다.
    private func cleanupStaleSessionIfFirstLaunch() {
        let cleanupKey = "com.microcosm.hasCompletedInitialInstallCleanup"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: cleanupKey) else { return }
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        defaults.set(true, forKey: cleanupKey)
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
