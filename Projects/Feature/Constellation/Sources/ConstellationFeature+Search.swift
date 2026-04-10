import ComposableArchitecture

extension ConstellationFeature {
    /// 별자리 검색 토글 / 쿼리 변경 / 결과 선택 시 네비게이션 의도 기록.
    func reduceSearch(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .toggleSearch:
            state.isSearching.toggle()
            if !state.isSearching {
                state.searchText = ""
            }
            return .none

        case .searchTextChanged(let text):
            state.searchText = text
            return .none

        case .selectSearchResult(let id):
            state.isSearching = false
            state.searchText = ""
            state.pendingNavigation = .zoomToConstellation(id)
            return .none

        default:
            return .none
        }
    }
}
