import ComposableArchitecture
import Foundation

extension ConstellationFeature {
    /// 최초 1회 가이드 플로우(환영 → 별자리 탭 → 별 탭 → 목표 등록 → 클로징).
    ///
    /// 플래그 저장소는 Firestore `users/{uid}.hasSeenConstellationGuide` 이다.
    /// (UserDefaults 는 앱 삭제 시 초기화되어, 재설치한 동일 계정이 가이드를 또 보게 되던 문제가 있어 Firebase 로 이관)
    /// 이전 버전에서 UserDefaults 에 기록된 사용자는 onAppear 시 1회 Firestore 로 마이그레이션된다.
    func reduceGuide(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .send(.checkGuide)

        case .checkGuide:
            // 이미 Firestore 에 완료로 기록돼 있으면 표시하지 않는다.
            if state.hasSeenConstellationGuide {
                return .none
            }
            // 레거시: UserDefaults 에 완료 기록이 있으면 Firestore 로 마이그레이션 후 표시하지 않는다.
            if UserDefaults.standard.bool(forKey: Self.legacyGuideKey) {
                state.hasSeenConstellationGuide = true
                return .run { [userClient, authClient] _ in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try? await userClient.markConstellationGuideSeen(userId)
                }
            }
            // 신규(또는 재설치) 사용자 → 가이드 시작.
            state.showGuide = true
            state.guideStep = .welcome
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
                return .none
            case .closing:
                // 가이드 완료
                state.showGuide = false
                state.guideStep = nil
                state.hasSeenConstellationGuide = true
                return .run { [userClient, authClient] _ in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try? await userClient.markConstellationGuideSeen(userId)
                }
            default:
                // tapConstellation, tapStar, registerGoal은 유저 인터랙션으로 진행
                return .none
            }

        case .dismissGuide:
            state.showGuide = false
            state.guideStep = nil
            state.hasSeenConstellationGuide = true
            return .run { [userClient, authClient] _ in
                guard let userId = authClient.currentUser()?.uid else { return }
                try? await userClient.markConstellationGuideSeen(userId)
            }

        default:
            return .none
        }
    }

    /// 레거시 UserDefaults 키 (Firestore 이관 전 버전 호환용).
    static var legacyGuideKey: String { "hasSeenConstellationGuide" }
}
