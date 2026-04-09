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
        public var showNicknameChange = false
        public var nicknameState = NicknameFeature.State(isOnboarding: false)

        public init(
            userProfile: UserProfile = UserProfile(),
            displayName: String? = nil,
            allRecords: [Record] = [],
            showSignOutAlert: Bool = false,
            showDeleteAlert: Bool = false,
            showNicknameChange: Bool = false,
            nicknameState: NicknameFeature.State = NicknameFeature.State(isOnboarding: false)
        ) {
            self.userProfile = userProfile
            self.displayName = displayName
            self.allRecords = allRecords
            self.showSignOutAlert = showSignOutAlert
            self.showDeleteAlert = showDeleteAlert
            self.showNicknameChange = showNicknameChange
            self.nicknameState = nicknameState
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case signOutTapped
        case confirmSignOut
        case dismissSignOutAlert
        case deleteAccountTapped
        case confirmDeleteAccount
        case dismissDeleteAlert
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
                return .run { send in
                    try await authClient.deleteAccount()
                    await send(.delegate(.didDeleteAccount))
                }

            case .dismissDeleteAlert:
                state.showDeleteAlert = false
                return .none

            case .resetOnboardingTapped:
                return .run { _ in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try await userClient.resetOnboarding(userId)
                }

            case .changeNicknameTapped:
                state.nicknameState = NicknameFeature.State(isOnboarding: false)
                state.nicknameState.nickname = state.userProfile.nickname ?? ""
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
