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
                state.mainTab.universe.userDisplayName = profile.nickname ?? state.displayName
                state.mainTab.universe.hasCompletedOnboarding = profile.hasCompletedOnboarding
                state.mainTab.profile.userProfile = profile
                state.mainTab.profile.displayName = profile.nickname ?? state.displayName
                state.mainTab.userId = state.userId

                if state.mode == .splash || state.mode == .login {
                    if state.userId == nil {
                        state.mode = .login
                    } else {
                        state.mode = .main
                    }
                }
                return .none

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
