import ComposableArchitecture
import DomainClient
import DomainEntity

@Reducer
public struct NicknameFeature {
    @ObservableState
    public struct State: Equatable {
        public var nickname = ""
        public var isChecking = false
        public var isAvailable: Bool?
        public var errorMessage: String?
        public var isOnboarding: Bool
        public var isSaving = false

        public init(
            nickname: String = "",
            isChecking: Bool = false,
            isAvailable: Bool? = nil,
            errorMessage: String? = nil,
            isOnboarding: Bool = true,
            isSaving: Bool = false
        ) {
            self.nickname = nickname
            self.isChecking = isChecking
            self.isAvailable = isAvailable
            self.errorMessage = errorMessage
            self.isOnboarding = isOnboarding
            self.isSaving = isSaving
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case nicknameChanged(String)
        case checkNickname
        case nicknameCheckResult(Bool)
        case nicknameCheckFailed(String)
        case confirmTapped
        case saveCompleted
        case delegate(Delegate)

        public enum Delegate {
            case nicknameSet
        }
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .nicknameChanged(let text):
                let filtered = String(text.prefix(10))
                state.nickname = filtered
                state.isAvailable = nil
                state.errorMessage = nil
                return .none

            case .checkNickname:
                let trimmed = state.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count >= 2 else {
                    state.errorMessage = "닉네임은 2자 이상이어야 해요"
                    return .none
                }
                guard trimmed.count <= 10 else {
                    state.errorMessage = "닉네임은 10자 이하여야 해요"
                    return .none
                }
                state.isChecking = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let available = try await userClient.checkNickname(trimmed)
                        await send(.nicknameCheckResult(available))
                    } catch {
                        await send(.nicknameCheckFailed("중복 검사에 실패했어요"))
                    }
                }

            case .nicknameCheckResult(let available):
                state.isChecking = false
                state.isAvailable = available
                if !available {
                    state.errorMessage = "이미 사용 중인 닉네임이에요"
                }
                return .none

            case .nicknameCheckFailed(let message):
                state.isChecking = false
                state.isSaving = false
                state.errorMessage = message
                return .none

            case .confirmTapped:
                guard state.isAvailable == true else { return .none }
                let trimmed = state.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                state.isSaving = true
                return .run { send in
                    guard let userId = authClient.currentUser()?.uid else {
                        await send(.nicknameCheckFailed("로그인이 만료되었어요. 다시 시도해주세요"))
                        return
                    }
                    do {
                        try await userClient.setNickname(userId, trimmed)
                        await send(.saveCompleted)
                    } catch UserClientError.nicknameTaken {
                        await send(.nicknameCheckFailed("이미 사용 중인 닉네임이에요"))
                    } catch UserClientError.nicknameInvalid {
                        await send(.nicknameCheckFailed("사용할 수 없는 닉네임이에요"))
                    } catch {
                        await send(.nicknameCheckFailed("저장에 실패했어요. 잠시 후 다시 시도해주세요"))
                    }
                }

            case .saveCompleted:
                state.isSaving = false
                return .send(.delegate(.nicknameSet))

            case .delegate:
                return .none

            case .binding:
                return .none
            }
        }
    }
}
