import ComposableArchitecture
import DomainEntity

extension UniverseFeature {
    /// 기록 저장 파이프라인 (요청 → AI 분석 → Star 생성) 및 패널 UI 상태 처리.
    func reduceRecordPanel(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .addRecordRequested(let record):
            return .run { [authClient, recordClient] send in
                guard let userId = authClient.currentUser()?.uid else { return }
                try await recordClient.addRecord(userId, record)
            } catch: { _, _ in
                // Firestore 오프라인 캐시로 즉각 실패가 드물며,
                // recordClient.observe가 실시간 상태를 반영하므로 별도 에러 액션 불필요
            }

        case .recordsUpdated(let records):
            state.allRecords = records
            // 최초 records yield 후에만 onboarding 결정을 신뢰. 이후 보류 중인
            // checkOnboarding 요청을 리졸브한다. (UniverseView setupScene → records 미도착
            // 상태에서 잘못 welcome으로 진입하는 레이스 방지)
            if !state.hasReceivedInitialRecords {
                state.hasReceivedInitialRecords = true
                if state.pendingOnboardingCheck {
                    state.pendingOnboardingCheck = false
                    return .send(.checkOnboarding)
                }
            }
            return .none

        case .openRecordPanel:
            if state.onboardingStep != .createStarPrompt {
                guard state.canCreateRecord else {
                    state.showLimitAlert = true
                    return .none
                }
            }
            state.recordContent = ""
            state.starName = ""
            state.analyzedProfile = nil
            state.isAnalyzingColor = false
            state.showRecordPanel = true
            return .none

        case .dismissPanel:
            state.recordContent = ""
            state.starName = ""
            state.analyzedProfile = nil
            state.isAnalyzingColor = false
            state.showRecordPanel = false
            return .none

        case .saveRecord:
            let trimmed = state.recordContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .none }
            state.isAnalyzingColor = true
            let content = trimmed
            return .run { send in
                // Fallback chain: analyzeEmotion → analyzeColor → fallback
                do {
                    let profile = try await openAIClient.analyzeEmotion(content)
                    await send(.profileAnalyzed(profile))
                } catch {
                    do {
                        let color = try await openAIClient.analyzeColor(content)
                        await send(.colorAnalyzed(color))
                    } catch {
                        await send(.profileAnalysisFailed)
                    }
                }
            }

        case .profileAnalyzed(let profile):
            state.pendingStarCreation = Self.composePendingStarCreation(state: state, profile: profile)
            state.analyzedProfile = profile
            state.isAnalyzingColor = false
            state.showRecordPanel = false
            if state.onboardingStep == .createStarPrompt {
                state.onboardingStep = .closingMessage
            }
            return .none

        case .colorAnalyzed(let color):
            let derived = StarVisualProfile.from(legacyColor: color)
            state.pendingStarCreation = Self.composePendingStarCreation(state: state, profile: derived)
            state.analyzedProfile = derived
            state.isAnalyzingColor = false
            state.showRecordPanel = false
            if state.onboardingStep == .createStarPrompt {
                state.onboardingStep = .closingMessage
            }
            return .none

        case .profileAnalysisFailed:
            state.pendingStarCreation = Self.composePendingStarCreation(state: state, profile: .fallback)
            state.analyzedProfile = .fallback
            state.isAnalyzingColor = false
            state.showRecordPanel = false
            if state.onboardingStep == .createStarPrompt {
                state.onboardingStep = .closingMessage
            }
            return .none

        case .clearPendingStarCreation:
            state.pendingStarCreation = nil
            return .none

        default:
            return .none
        }
    }

    /// 분석 완료 시점의 recordContent/starName/isOnboarding을 스냅샷으로 묶어
    /// scene에 전달할 pending 페이로드를 구성한다. onboardingStep 전이 전에 호출해야 한다.
    private static func composePendingStarCreation(
        state: State,
        profile: StarVisualProfile
    ) -> State.PendingStarCreation {
        State.PendingStarCreation(
            content: state.recordContent.trimmingCharacters(in: .whitespacesAndNewlines),
            starName: state.starName,
            profile: profile,
            isOnboardingRecord: state.onboardingStep == .createStarPrompt
        )
    }
}
