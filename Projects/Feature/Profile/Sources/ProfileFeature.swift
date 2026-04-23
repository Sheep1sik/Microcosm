import ComposableArchitecture
import DomainClient
import DomainEntity
import FeatureNickname

@Reducer
public struct ProfileFeature {
    @ObservableState
    public struct State: Equatable {
        public var userProfile: UserProfile = UserProfile()
        public var displayName: String?
        public var allRecords: [Record] = []
        public var showSignOutAlert = false
        public var showDeleteAlert = false
        public var deleteFailure: DeleteFailure?
        public var showNicknameChange = false
        public var nicknameState = NicknameFeature.State(isOnboarding: false)

        public init(
            userProfile: UserProfile = UserProfile(),
            displayName: String? = nil,
            allRecords: [Record] = [],
            showSignOutAlert: Bool = false,
            showDeleteAlert: Bool = false,
            deleteFailure: DeleteFailure? = nil,
            showNicknameChange: Bool = false,
            nicknameState: NicknameFeature.State = NicknameFeature.State(isOnboarding: false)
        ) {
            self.userProfile = userProfile
            self.displayName = displayName
            self.allRecords = allRecords
            self.showSignOutAlert = showSignOutAlert
            self.showDeleteAlert = showDeleteAlert
            self.deleteFailure = deleteFailure
            self.showNicknameChange = showNicknameChange
            self.nicknameState = nicknameState
        }
    }

    public enum DeleteFailure: Equatable {
        case requiresRecentLogin
        case network
        case general

        public var message: String {
            switch self {
            case .requiresRecentLogin: return "보안을 위해 다시 로그인 후\n탈퇴를 시도해주세요"
            case .network: return "네트워크 연결을 확인해주세요"
            case .general: return "잠시 후 다시 시도해주세요"
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case signOutTapped
        case confirmSignOut
        case dismissSignOutAlert
        case deleteAccountTapped
        case confirmDeleteAccount
        case deleteAccountFailed(DeleteFailure)
        case dismissDeleteAlert
        case dismissDeleteError
        case changeNicknameTapped
        case dismissNicknameChange
        case resetOnboardingTapped
        case nickname(NicknameFeature.Action)
        case delegate(Delegate)

        public enum Delegate {
            case didSignOut
            case didDeleteAccount
        }
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.userClient) var userClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.nicknameState, action: \.nickname) {
            NicknameFeature()
        }

        Reduce { state, action in
            switch action {
            case .signOutTapped:
                state.showSignOutAlert = true
                return .none

            case .confirmSignOut:
                state.showSignOutAlert = false
                return .run { send in
                    authClient.clearLocalData()
                    try authClient.signOut()
                    await send(.delegate(.didSignOut))
                }

            case .dismissSignOutAlert:
                state.showSignOutAlert = false
                return .none

            case .deleteAccountTapped:
                state.showDeleteAlert = true
                return .none

            case .confirmDeleteAccount:
                state.showDeleteAlert = false
                return .run { [userId = authClient.currentUser()?.uid] send in
                    if let userId {
                        try await userClient.deleteAllData(userId)
                    }
                    try await authClient.deleteAccount()
                    authClient.clearLocalData()
                    await send(.delegate(.didDeleteAccount))
                } catch: { error, send in
                    if let authError = error as? AuthError {
                        switch authError {
                        case .requiresRecentLogin:
                            await send(.deleteAccountFailed(.requiresRecentLogin))
                        case .network:
                            await send(.deleteAccountFailed(.network))
                        default:
                            await send(.deleteAccountFailed(.general))
                        }
                    } else {
                        await send(.deleteAccountFailed(.general))
                    }
                }

            case .deleteAccountFailed(let failure):
                state.deleteFailure = failure
                return .none

            case .dismissDeleteAlert:
                state.showDeleteAlert = false
                return .none

            case .dismissDeleteError:
                let failure = state.deleteFailure
                state.deleteFailure = nil
                if failure == .requiresRecentLogin {
                    return .run { send in
                        try authClient.signOut()
                        authClient.clearLocalData()
                        await send(.delegate(.didSignOut))
                    } catch: { _, send in
                        authClient.clearLocalData()
                        await send(.delegate(.didSignOut))
                    }
                }
                return .none

            case .resetOnboardingTapped:
                return .run { _ in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try await userClient.resetOnboarding(userId)
                }

            case .changeNicknameTapped:
                state.nicknameState = NicknameFeature.State(
                    nickname: state.userProfile.nickname ?? "",
                    isOnboarding: false
                )
                state.showNicknameChange = true
                return .none

            case .dismissNicknameChange:
                state.showNicknameChange = false
                return .none

            case .nickname(.delegate(.nicknameSet)):
                state.showNicknameChange = false
                return .none

            case .nickname:
                return .none

            case .delegate:
                return .none

            case .binding:
                return .none
            }
        }
    }
}
