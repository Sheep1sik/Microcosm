import ComposableArchitecture
import DomainEntity

extension UniverseFeature {
    /// SpriteKit scene 콜백 액션 처리. State 동기화 및 온보딩 이벤트 포워딩.
    func reduceSceneCallbacks(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .sceneDidEnterGalaxyDetail(let key, let records):
            state.isInGalaxyDetail = true
            state.currentYearMonth = key
            state.currentDetailRecords = records
            return .send(.onboarding(.enteredGalaxyDetail))

        case .sceneDidExitGalaxyDetail:
            state.isInGalaxyDetail = false
            state.currentYearMonth = nil
            state.currentDetailRecords = []
            return .none

        case .sceneDidUpdateDetailRecords(let records):
            state.currentDetailRecords = records
            return .none

        case .sceneGalaxyBirthCompleted:
            return .send(.onboarding(.galaxyBirthCompleted))

        case .sceneGalaxyScreenCenterUpdated(let center):
            return .send(.onboarding(.galaxyScreenCenterUpdated(center)))

        case .scenePreviewImagesUpdated:
            state.previewRevision &+= 1
            return .none

        default:
            return .none
        }
    }
}
