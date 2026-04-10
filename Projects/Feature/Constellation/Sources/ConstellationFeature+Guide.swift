import ComposableArchitecture
import Foundation

extension ConstellationFeature {
    /// 최초 1회 가이드 플로우(환영 → 별자리 탭 → 별 탭 → 목표 등록 → 클로징).
    /// UserDefaults `hasSeenConstellationGuide` 플래그로 1회 노출을 보장한다.
    func reduceGuide(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .send(.checkGuide)

        case .checkGuide:
            let hasSeenGuide = UserDefaults.standard.bool(forKey: "hasSeenConstellationGuide")
            if !hasSeenGuide {
                state.showGuide = true
                state.guideStep = .welcome
            }
            return .none

        case .advanceGuide:
            guard let current = state.guideStep else {
                state.showGuide = false
                return .none
            }
            switch current {
            case .welcome:
                // 환영 → 별자리 탭 안내 (유저가 직접 조작)
                state.guideStep = .tapConstellation
            case .closing:
                // 가이드 완료
                state.showGuide = false
                state.guideStep = nil
                UserDefaults.standard.set(true, forKey: "hasSeenConstellationGuide")
            default:
                // tapConstellation, tapStar, registerGoal은 유저 인터랙션으로 진행
                break
            }
            return .none

        case .dismissGuide:
            state.showGuide = false
            state.guideStep = nil
            UserDefaults.standard.set(true, forKey: "hasSeenConstellationGuide")
            return .none

        default:
            return .none
        }
    }
}
