import SwiftUI
import ComposableArchitecture
import DomainEntity
import DomainClient
import FeatureSplash
import FeatureAuth
import FeatureNickname
import FeatureMain

struct RootView: View {
    @Bindable var store: StoreOf<RootFeature>

    var body: some View {
        Group {
            switch store.mode {
            case .splash:
                SplashView(store: store.scope(state: \.splash, action: \.splash))
            case .login:
                LoginView(store: store.scope(state: \.login, action: \.login))
            case .nickname:
                NicknameInputView(store: store.scope(state: \.nickname, action: \.nickname))
            case .main:
                MainTabView(store: store.scope(state: \.mainTab, action: \.mainTab))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.mode)
        .onAppear { store.send(.onAppear) }
    }
}
