import XCTest
import ComposableArchitecture
@testable import FeatureUniverse
import DomainEntity

@MainActor
final class UniverseFeatureNavigationTests: XCTestCase {

    // MARK: - navigateToGalaxy

    func test_navigateToGalaxy_pendingNavigation_galaxy로_설정() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        await store.send(.navigateToGalaxy("2026-04")) {
            $0.pendingNavigation = .galaxy("2026-04")
        }
    }

    // MARK: - navigateToGalaxyThenStar

    func test_navigateToGalaxyThenStar_pendingNavigation_galaxyThenStar로_설정() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        let record = Record(content: "별 생성 기록")
        await store.send(.navigateToGalaxyThenStar(yearMonth: "2026-04", record: record)) {
            $0.pendingNavigation = .galaxyThenStar(yearMonth: "2026-04", record: record)
        }
    }

    // MARK: - navigateToStar

    func test_navigateToStar_pendingNavigation_star로_설정() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        let record = Record(content: "점프 대상 별")
        await store.send(.navigateToStar(record)) {
            $0.pendingNavigation = .star(record)
        }
    }

    // MARK: - 교체 동작

    func test_navigate_연속호출_마지막값만_남음() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        await store.send(.navigateToGalaxy("2026-03")) {
            $0.pendingNavigation = .galaxy("2026-03")
        }
        await store.send(.navigateToGalaxy("2026-04")) {
            $0.pendingNavigation = .galaxy("2026-04")
        }
        let record = Record(content: "마지막")
        await store.send(.navigateToStar(record)) {
            $0.pendingNavigation = .star(record)
        }
    }
}
