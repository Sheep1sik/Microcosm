import Foundation
import ComposableArchitecture
import DomainClient
import FeatureNickname

public enum OnboardingStep: Int, Equatable, Sendable {
    case welcome
    case nicknameInput
    case galaxyBirthIntro
    case monthlyGalaxyGuide
    case tapGalaxyPrompt
    case createStarPrompt
    case closingMessage
    case completed
}

@Reducer
public struct OnboardingFeature {
    @ObservableState
    public struct State: Equatable {
        public var hasCompleted: Bool = false
        public var step: OnboardingStep? = nil
        public var galaxyScreenCenter: CGPoint?
        public var hasReceivedInitialRecords: Bool = false
        public var hasReceivedInitialProfile: Bool = false
        public var pendingCheck: Bool = false
        public var hasExistingRecords: Bool = false
        public var nickname: NicknameFeature.State = .init()
        public var userDisplayName: String?

        public var isActive: Bool { step != nil && step != .completed }

        public init(
            hasCompleted: Bool = false,
            step: OnboardingStep? = nil,
            galaxyScreenCenter: CGPoint? = nil,
            hasReceivedInitialRecords: Bool = false,
            hasReceivedInitialProfile: Bool = false,
            pendingCheck: Bool = false,
            hasExistingRecords: Bool = false,
            nickname: NicknameFeature.State = .init(),
            userDisplayName: String? = nil
        ) {
            self.hasCompleted = hasCompleted
            self.step = step
            self.galaxyScreenCenter = galaxyScreenCenter
            self.hasReceivedInitialRecords = hasReceivedInitialRecords
            self.hasReceivedInitialProfile = hasReceivedInitialProfile
            self.pendingCheck = pendingCheck
            self.hasExistingRecords = hasExistingRecords
            self.nickname = nickname
            self.userDisplayName = userDisplayName
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        case check
        case advanceFromWelcome
        case advanceFromGuide
        case nickname(NicknameFeature.Action)
        case complete
        case skip

        // Universe 에서 포워딩되는 이벤트
        case recordsReceived(hasRecords: Bool)
        case profileReceived
        case galaxyBirthCompleted
        case enteredGalaxyDetail
        case galaxyScreenCenterUpdated(CGPoint?)
        case starCreated
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.userClient) var userClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.nickname, action: \.nickname) {
            NicknameFeature()
        }

        Reduce { state, action in
            switch action {
            case .check:
                guard state.hasReceivedInitialRecords, state.hasReceivedInitialProfile else {
                    state.pendingCheck = true
                    return .none
                }
                guard !state.hasCompleted else { return .none }
                if state.hasExistingRecords {
                    state.hasCompleted = true
                    return .none
                }
                state.step = .welcome
                return .none

            case .recordsReceived(let hasRecords):
                state.hasExistingRecords = hasRecords
                if !state.hasReceivedInitialRecords {
                    state.hasReceivedInitialRecords = true
                    if state.pendingCheck, state.hasReceivedInitialProfile {
                        state.pendingCheck = false
                        return .send(.check)
                    }
                }
                return .none

            case .profileReceived:
                if !state.hasReceivedInitialProfile {
                    state.hasReceivedInitialProfile = true
                    if state.pendingCheck, state.hasReceivedInitialRecords {
                        state.pendingCheck = false
                        return .send(.check)
                    }
                }
                return .none

            case .advanceFromWelcome:
                guard state.step == .welcome else { return .none }
                state.step = .nicknameInput
                return .none

            case .nickname(.delegate(.nicknameSet)):
                state.userDisplayName = state.nickname.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                state.step = .galaxyBirthIntro
                return .none

            case .nickname:
                return .none

            case .galaxyBirthCompleted:
                if state.step == .galaxyBirthIntro {
                    state.step = .monthlyGalaxyGuide
                }
                return .none

            case .advanceFromGuide:
                guard state.step == .monthlyGalaxyGuide else { return .none }
                state.step = .tapGalaxyPrompt
                return .none

            case .enteredGalaxyDetail:
                if state.step == .tapGalaxyPrompt {
                    state.step = .createStarPrompt
                }
                return .none

            case .starCreated:
                if state.step == .createStarPrompt {
                    state.step = .closingMessage
                }
                return .none

            case .galaxyScreenCenterUpdated(let center):
                state.galaxyScreenCenter = center
                return .none

            case .complete:
                guard state.step != .completed else { return .none }
                state.step = .completed
                state.hasCompleted = true
                return .run { [authClient, userClient] _ in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    await Self.markOnboardingCompletedWithRetry(userId: userId, userClient: userClient)
                }

            case .skip:
                state.step = .completed
                state.hasCompleted = true
                return .run { [authClient, userClient] _ in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    await Self.markOnboardingCompletedWithRetry(userId: userId, userClient: userClient)
                }

            case .binding:
                return .none
            }
        }
    }

    /// 온보딩 완료 플래그를 서버에 저장한다. 최대 3회 재시도하며, 실패해도 로컬 상태는 유지한다.
    static func markOnboardingCompletedWithRetry(
        userId: String,
        userClient: UserClient
    ) async {
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                try await userClient.markOnboardingCompleted(userId)
                return
            } catch {
                if attempt == maxAttempts { return }
                let delayNs = UInt64(attempt) * 500_000_000 * UInt64(attempt)
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
    }
}
