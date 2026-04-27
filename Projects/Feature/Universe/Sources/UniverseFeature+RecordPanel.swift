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
            // 최초 records yield 시 온보딩에 알림. hasExistingRecords 도 함께 전달.
            if !state.onboarding.hasReceivedInitialRecords {
                return .send(.onboarding(.recordsReceived(hasRecords: !records.isEmpty)))
            }
            return .none

        case .openRecordPanel:
            if state.onboarding.step != .createStarPrompt {
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
            return .send(.onboarding(.starCreated))

        case .colorAnalyzed(let color):
            let derived = StarVisualProfile.from(legacyColor: color)
            state.pendingStarCreation = Self.composePendingStarCreation(state: state, profile: derived)
            state.analyzedProfile = derived
            state.isAnalyzingColor = false
            state.showRecordPanel = false
            return .send(.onboarding(.starCreated))

        case .profileAnalysisFailed:
            state.pendingStarCreation = Self.composePendingStarCreation(state: state, profile: .fallback)
            state.analyzedProfile = .fallback
            state.isAnalyzingColor = false
            state.showRecordPanel = false
            return .send(.onboarding(.starCreated))

        case .clearPendingStarCreation:
            state.pendingStarCreation = nil
            return .none

        default:
            return .none
        }
    }

    /// 분석 완료 시점의 recordContent/starName/isOnboarding을 스냅샷으로 묶어
    /// scene에 전달할 pending 페이로드를 구성한다.
    private static func composePendingStarCreation(
        state: State,
        profile: StarVisualProfile
    ) -> State.PendingStarCreation {
        State.PendingStarCreation(
            content: state.recordContent.trimmingCharacters(in: .whitespacesAndNewlines),
            starName: state.starName,
            profile: profile,
            isOnboardingRecord: state.onboarding.step == .createStarPrompt
        )
    }
}
