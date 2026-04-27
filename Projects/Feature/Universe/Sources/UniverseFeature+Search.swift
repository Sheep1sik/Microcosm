import ComposableArchitecture

extension UniverseFeature {
    /// 검색 디바운스/종료 처리.
    func reduceSearch(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .searchTextChanged(let text):
            state.searchText = text
            return .run { send in
                try await Task.sleep(for: .milliseconds(250))
                await send(.debouncedQueryUpdated(text))
            }
            .cancellable(id: CancelID.debounce, cancelInFlight: true)

        case .debouncedQueryUpdated(let query):
            state.debouncedQuery = query
            return .none

        case .closeSearch:
            state.searchText = ""
            state.debouncedQuery = ""
            state.isSearching = false
            return .cancel(id: CancelID.debounce)

        default:
            return .none
        }
    }
}
