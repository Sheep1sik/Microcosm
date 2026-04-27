import ComposableArchitecture

extension UniverseFeature {
    /// View 에서 scene 메서드를 호출하기 위해 네비게이션 의도를 State 에 기록한다.
    func reduceNavigation(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .navigateToGalaxy(let yearMonth):
            state.pendingNavigation = .galaxy(yearMonth)
            return .none

        case .navigateToGalaxyThenStar(let yearMonth, let record):
            state.pendingNavigation = .galaxyThenStar(yearMonth: yearMonth, record: record)
            return .none

        case .navigateToStar(let record):
            state.pendingNavigation = .star(record)
            return .none

        default:
            return .none
        }
    }
}
