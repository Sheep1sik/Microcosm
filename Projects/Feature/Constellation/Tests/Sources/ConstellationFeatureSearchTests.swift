import XCTest
import ComposableArchitecture
@testable import FeatureConstellation

@MainActor
final class ConstellationFeatureSearchTests: XCTestCase {

    // MARK: - toggleSearch

    func test_toggleSearch_off에서_on() async {
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }

        await store.send(.toggleSearch) {
            $0.isSearching = true
        }
    }

    func test_toggleSearch_on에서_off_searchText도_초기화() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                isSearching: true,
                searchText: "ORI"
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.toggleSearch) {
            $0.isSearching = false
            $0.searchText = ""
        }
    }

    // MARK: - searchTextChanged

    func test_searchTextChanged_텍스트_반영() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                isSearching: true
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.searchTextChanged("오리온")) {
            $0.searchText = "오리온"
        }
    }

    // MARK: - selectSearchResult

    func test_selectSearchResult_검색종료_pendingNavigation_설정() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                isSearching: true,
                searchText: "오리온"
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.selectSearchResult("ORI")) {
            $0.isSearching = false
            $0.searchText = ""
            $0.pendingNavigation = .zoomToConstellation("ORI")
        }
    }
}
