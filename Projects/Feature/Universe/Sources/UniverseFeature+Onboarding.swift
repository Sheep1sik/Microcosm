import ComposableArchitecture
import DomainClient

extension UniverseFeature {
    /// 온보딩 플로우 전반: welcome → nickname → galaxyBirth → guide → tapGalaxy → createStar → closing → completed.
    func reduceOnboarding(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .checkOnboarding:
            // records observer가 최초 yield 하기 전이면 결정을 보류.
            // recordsUpdated 첫 호출 시 자동으로 다시 평가한다.
            guard state.hasReceivedInitialRecords else {
                state.pendingOnboardingCheck = true
                return .none
            }
            guard !state.hasCompletedOnboarding else { return .none }
            if !state.allRecords.isEmpty {
                state.hasCompletedOnboarding = true
                return .none
            }
            state.onboardingStep = .welcome
            return .none

        case .onboardingAdvanceFromWelcome:
            guard state.onboardingStep == .welcome else { return .none }
            state.onboardingStep = .nicknameInput
            return .none

        case .onboardingNicknameChanged(let text):
            state.onboardingNickname = text
            state.onboardingNicknameError = nil
            state.onboardingNicknameAvailable = nil
            return .none

        case .onboardingCheckNickname:
            let trimmed = state.onboardingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2, trimmed.count <= 10 else {
                state.onboardingNicknameError = "2~10자로 입력해주세요"
                return .none
            }
            state.onboardingNicknameChecking = true
            state.onboardingNicknameError = nil
            state.onboardingNicknameAvailable = nil
            let nickname = trimmed
            return .run { send in
                do {
                    let available = try await userClient.checkNickname(nickname)
                    await send(.onboardingNicknameCheckResult(available))
                } catch {
                    await send(.onboardingNicknameCheckFailed("확인 중 오류가 발생했어요"))
                }
            }

        case .onboardingNicknameCheckResult(let available):
            state.onboardingNicknameChecking = false
            if available {
                state.onboardingNicknameAvailable = true
                state.onboardingNicknameError = nil
            } else {
                state.onboardingNicknameAvailable = false
                state.onboardingNicknameError = "이미 사용 중인 닉네임이에요"
            }
            return .none

        case .onboardingNicknameCheckFailed(let message):
            state.onboardingNicknameChecking = false
            state.onboardingNicknameSaving = false
            state.onboardingNicknameError = message
            return .none

        case .onboardingNicknameConfirm:
            let trimmed = state.onboardingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
            guard state.onboardingNicknameAvailable == true else { return .none }
            state.onboardingNicknameSaving = true
            state.onboardingNicknameError = nil
            let nickname = trimmed
            return .run { send in
                guard let userId = authClient.currentUser()?.uid else {
                    await send(.onboardingNicknameCheckFailed("로그인이 만료되었어요. 다시 시도해주세요"))
                    return
                }
                do {
                    try await userClient.setNickname(userId, nickname)
                    await send(.onboardingNicknameSaveCompleted)
                } catch UserClientError.nicknameTaken {
                    await send(.onboardingNicknameCheckFailed("이미 사용 중인 닉네임이에요"))
                } catch UserClientError.nicknameInvalid {
                    await send(.onboardingNicknameCheckFailed("사용할 수 없는 닉네임이에요"))
                } catch {
                    await send(.onboardingNicknameCheckFailed("저장에 실패했어요. 잠시 후 다시 시도해주세요"))
                }
            }

        case .onboardingNicknameSaveCompleted:
            state.onboardingNicknameSaving = false
            state.userDisplayName = state.onboardingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
            state.onboardingStep = .galaxyBirthIntro
            return .none

        case .onboardingAdvanceFromGuide:
            guard state.onboardingStep == .monthlyGalaxyGuide else { return .none }
            state.onboardingStep = .tapGalaxyPrompt
            return .none

        case .onboardingComplete:
            guard state.onboardingStep != .completed else { return .none }
            state.onboardingStep = .completed
            state.hasCompletedOnboarding = true
            return .run { _ in
                guard let userId = authClient.currentUser()?.uid else { return }
                await Self.markOnboardingCompletedWithRetry(userId: userId, userClient: userClient)
            }

        case .skipOnboarding:
            state.onboardingStep = .completed
            state.hasCompletedOnboarding = true
            return .run { _ in
                guard let userId = authClient.currentUser()?.uid else { return }
                await Self.markOnboardingCompletedWithRetry(userId: userId, userClient: userClient)
            }

        default:
            return .none
        }
    }

    /// 온보딩 완료 플래그를 서버에 저장한다. 최대 3회 재시도하며, 실패해도 로컬 상태는 유지한다.
    /// - Note: 전부 실패해도 다음 세션에서 사용자가 서버 상태와 동기화될 기회가 있으므로 치명적이지 않다.
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
                if attempt == maxAttempts {
                    // 모든 재시도 실패: 로컬 상태는 이미 completed이므로 사용자 경험은 유지.
                    // 다음 앱 실행 시 서버 동기화로 복구될 수 있다.
                    return
                }
                // Exponential backoff: 0.5s, 1.5s
                let delayNs = UInt64(attempt) * 500_000_000 * UInt64(attempt)
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
    }
}
