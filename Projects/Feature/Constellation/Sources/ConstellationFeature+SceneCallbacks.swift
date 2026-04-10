import ComposableArchitecture

extension ConstellationFeature {
    /// SpriteKit scene 콜백: 별자리 진입/종료/별 탭/빈 공간 탭.
    /// 가이드(guideStep) 진행 분기도 여기서 처리한다.
    func reduceSceneCallbacks(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .sceneDidEnterConstellationDetail(let id):
            state.isInConstellationDetail = true
            state.selectedConstellationId = id
            // 가이드: 별자리 탭 단계 완료
            if state.guideStep == .tapConstellation {
                state.guideStep = .tapStar
            }
            return .none

        case .sceneDidExitConstellationDetail:
            state.isInConstellationDetail = false
            state.selectedConstellationId = nil
            state.selectedStarIndex = nil
            state.showGoalPanel = false
            state.isEditingGoal = false
            return .none

        case .sceneDidTapStar(let constellationId, let starIndex):
            state.selectedConstellationId = constellationId
            state.selectedStarIndex = starIndex
            state.showGoalPanel = true
            state.isEditingGoal = false
            // 가이드: 별 탭 단계 완료 → 목표 등록 단계
            if state.guideStep == .tapStar {
                state.guideStep = .registerGoal
            }
            return .none

        case .sceneDidTapEmptyArea:
            if state.showGoalPanel && !state.isEditingGoal {
                state.showGoalPanel = false
                state.selectedStarIndex = nil
            }
            return .none

        default:
            return .none
        }
    }
}
