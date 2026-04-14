import ComposableArchitecture
import FirebaseAuth
import DomainEntity
import DomainClient
import FeatureSplash
import FeatureAuth
import FeatureMain

@Reducer
struct RootFeature {
    @ObservableState
    struct State: Equatable {
        var mode: Mode = .splash
        var splash = SplashFeature.State()
        var login = LoginFeature.State()
        var mainTab = MainTabFeature.State()

        // 인증 정보
        var userId: String?
        var displayName: String?
        var userProfile: UserProfile = UserProfile()

        enum Mode: Equatable {
            case splash
            case login
            case main
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case authStateChanged(FirebaseAuth.User?)
        case userProfileUpdated(UserProfile)
        case splash(SplashFeature.Action)
        case login(LoginFeature.Action)
        case mainTab(MainTabFeature.Action)
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.userClient) var userClient

    private enum CancelID { case authObserver, userObserver }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.splash, action: \.splash) { SplashFeature() }
        Scope(state: \.login, action: \.login) { LoginFeature() }
        Scope(state: \.mainTab, action: \.mainTab) { MainTabFeature() }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for await user in authClient.observeAuthState() {
                        await send(.authStateChanged(user))
                    }
                }.cancellable(id: CancelID.authObserver, cancelInFlight: true)

            case .authStateChanged(let user):
                state.userId = user?.uid
                state.displayName = user?.displayName
                if let userId = user?.uid {
                    // 인증되면 즉시 메인으로 전환. 프로필은 별도 스트림으로 따라옴.
                    // (네트워크 지연/실패로 프로필 스트림이 늦어도 메인 진입이 막히지 않음)
                    state.mainTab.userId = userId
                    if state.mode == .splash || state.mode == .login {
                        state.mode = .main
                    }
                    let displayName = user?.displayName
                    let email = user?.email
                    return .merge(
                        .run { _ in
                            try await userClient.createIfNeeded(userId)
                            if let displayName, !displayName.isEmpty {
                                try? await userClient.updateDisplayName(userId, displayName)
                            }
                            if let email, !email.isEmpty {
                                try? await userClient.updateEmail(userId, email)
                            }
                        },
                        .run { send in
                            for await profile in userClient.observe(userId) {
                                await send(.userProfileUpdated(profile))
                            }
                        }.cancellable(id: CancelID.userObserver, cancelInFlight: true)
                    )
                } else {
                    state.userProfile = UserProfile()
                    state.mode = .login
                    return .cancel(id: CancelID.userObserver)
                }

            case .userProfileUpdated(let profile):
                state.userProfile = profile
                return .send(.mainTab(.sessionUpdated(
                    userId: state.userId,
                    displayName: state.displayName,
                    profile: profile
                )))

            case .splash:
                return .none

            case .login:
                return .none

            case .mainTab(.profile(.delegate(.didSignOut))):
                state.mode = .login
                return .cancel(id: CancelID.userObserver)

            case .mainTab(.profile(.delegate(.didDeleteAccount))):
                state.mode = .login
                return .cancel(id: CancelID.userObserver)

            case .mainTab:
                return .none

            case .binding:
                return .none
            }
        }
    }
}
