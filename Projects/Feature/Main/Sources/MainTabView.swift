import SwiftUI
import ComposableArchitecture
import DomainEntity
import DomainClient
import FeatureUniverse
import FeatureConstellation
import FeatureProfile

public struct MainTabView: View {
    @Bindable var store: StoreOf<MainTabFeature>

    public init(store: StoreOf<MainTabFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            UniverseView(
                store: store.scope(state: \.universe, action: \.universe)
            )
            .tabItem {
                Image(systemName: "sparkles")
                Text("소우주")
            }
            .tag(MainTabFeature.State.Tab.universe)

            ConstellationView(
                store: store.scope(state: \.constellation, action: \.constellation)
            )
            .tabItem {
                Image(systemName: "star.circle")
                Text("별자리")
            }
            .tag(MainTabFeature.State.Tab.constellation)

            ProfileView(
                store: store.scope(state: \.profile, action: \.profile)
            )
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("프로필")
            }
            .tag(MainTabFeature.State.Tab.profile)
        }
        .tint(.white)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor(red: 0.01, green: 0.02, blue: 0.04, alpha: 0.9)
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.4)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.4)]
            appearance.stackedLayoutAppearance.selected.iconColor = .white
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            store.send(.onAppear)
        }
    }
}
