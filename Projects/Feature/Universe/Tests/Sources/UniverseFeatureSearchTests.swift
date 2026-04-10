import XCTest
import ComposableArchitecture
@testable import FeatureUniverse

@MainActor
final class UniverseFeatureSearchTests: XCTestCase {

    // MARK: - searchTextChanged

    func test_searchTextChanged_검색어즉시반영() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }
        // debounce effect 는 별도로 검증한다. 여기서는 즉시 state 반영만 본다.
        store.exhaustivity = .off

        await store.send(.searchTextChanged("2026")) {
            $0.searchText = "2026"
        }
    }

    func test_searchTextChanged_debounce후_query반영() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        await store.send(.searchTextChanged("2026-04")) {
            $0.searchText = "2026-04"
        }
        // 실제 Task.sleep(for: .milliseconds(250)) 기반 debounce.
        // TestClock 을 쓸 수 없으므로 timeout 을 넉넉히 주고 실제 방출을 기다린다.
        await store.receive(\.debouncedQueryUpdated, timeout: .seconds(2)) {
            $0.debouncedQuery = "2026-04"
        }
    }

    func test_searchTextChanged_연속입력_cancelInFlight_마지막만반영() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        // 앞 두 입력은 cancelInFlight 로 취소되고, 마지막 입력만 debouncedQueryUpdated 가 방출되어야 한다.
        await store.send(.searchTextChanged("2")) {
            $0.searchText = "2"
        }
        await store.send(.searchTextChanged("20")) {
            $0.searchText = "20"
        }
        await store.send(.searchTextChanged("2026")) {
            $0.searchText = "2026"
        }
        await store.receive(\.debouncedQueryUpdated, timeout: .seconds(2)) {
            $0.debouncedQuery = "2026"
        }
    }

    // MARK: - debouncedQueryUpdated

    func test_debouncedQueryUpdated_query만_반영() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        await store.send(.debouncedQueryUpdated("hello")) {
            $0.debouncedQuery = "hello"
        }
    }

    // MARK: - closeSearch

    func test_closeSearch_검색상태_전체초기화() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                searchText: "2026",
                isSearching: true,
                debouncedQuery: "2026"
            )
        ) {
            UniverseFeature()
        }

        await store.send(.closeSearch) {
            $0.searchText = ""
            $0.isSearching = false
            $0.debouncedQuery = ""
        }
    }

    func test_closeSearch_debounce중이어도_cancel되어_query방출없음() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        // 1. 검색어 입력 → debounce 시작
        await store.send(.searchTextChanged("abc")) {
            $0.searchText = "abc"
        }
        // 2. debounce 완료 전 closeSearch → 효과 취소
        await store.send(.closeSearch) {
            $0.searchText = ""
        }
        // debouncedQueryUpdated 는 방출되지 않아야 한다. exhaustive 모드에서
        // store.receive 를 호출하지 않는 것으로 검증된다.
    }
}
