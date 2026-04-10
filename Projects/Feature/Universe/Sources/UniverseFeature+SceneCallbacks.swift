import ComposableArchitecture
import DomainEntity

extension UniverseFeature {
    /// SpriteKit scene 콜백 액션 처리. State 동기화만 수행하고 Effect는 발생시키지 않는다.
    func reduceSceneCallbacks(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .sceneDidEnterGalaxyDetail(let key, let records):
            state.isInGalaxyDetail = true
            state.currentYearMonth = key
            state.currentDetailRecords = records
            if state.onboardingStep == .tapGalaxyPrompt {
                state.onboardingStep = .createStarPrompt
            }
            return .none

        case .sceneDidExitGalaxyDetail:
            state.isInGalaxyDetail = false
            state.currentYearMonth = nil
            state.currentDetailRecords = []
            return .none

        case .sceneDidUpdateDetailRecords(let records):
            state.currentDetailRecords = records
            return .none

        case .sceneGalaxyBirthCompleted:
            if state.onboardingStep == .galaxyBirthIntro {
                state.onboardingStep = .monthlyGalaxyGuide
            }
            return .none

        case .sceneGalaxyScreenCenterUpdated(let center):
            state.onboardingGalaxyScreenCenter = center
            return .none

        case .scenePreviewImagesUpdated:
            state.previewRevision &+= 1
            return .none

        default:
            return .none
        }
    }
}
