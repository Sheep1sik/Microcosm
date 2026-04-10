import XCTest
import ComposableArchitecture
@testable import FeatureUniverse
import DomainEntity

@MainActor
final class UniverseFeatureSceneCallbacksTests: XCTestCase {

    // MARK: - sceneDidEnterGalaxyDetail

    func test_sceneDidEnterGalaxyDetail_상세진입_상태반영() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        let records = [Record(content: "r1"), Record(content: "r2")]
        await store.send(.sceneDidEnterGalaxyDetail(key: "2026-04", records: records)) {
            $0.isInGalaxyDetail = true
            $0.currentYearMonth = "2026-04"
            $0.currentDetailRecords = records
        }
    }

    // MARK: - sceneDidExitGalaxyDetail

    func test_sceneDidExitGalaxyDetail_상세종료_상태초기화() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                isInGalaxyDetail: true,
                currentYearMonth: "2026-04",
                currentDetailRecords: [Record(content: "r1")]
            )
        ) {
            UniverseFeature()
        }

        await store.send(.sceneDidExitGalaxyDetail) {
            $0.isInGalaxyDetail = false
            $0.currentYearMonth = nil
            $0.currentDetailRecords = []
        }
    }

    // MARK: - sceneDidUpdateDetailRecords

    func test_sceneDidUpdateDetailRecords_현재상세기록만_갱신() async {
        let initialRecords = [Record(content: "old")]
        let store = TestStore(
            initialState: UniverseFeature.State(
                isInGalaxyDetail: true,
                currentDetailRecords: initialRecords
            )
        ) {
            UniverseFeature()
        }

        let updated = [Record(content: "new1"), Record(content: "new2")]
        await store.send(.sceneDidUpdateDetailRecords(updated)) {
            $0.currentDetailRecords = updated
        }
    }

    // MARK: - sceneGalaxyScreenCenterUpdated

    func test_sceneGalaxyScreenCenterUpdated_좌표반영() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        let center = CGPoint(x: 200, y: 400)
        await store.send(.sceneGalaxyScreenCenterUpdated(center)) {
            $0.onboardingGalaxyScreenCenter = center
        }
    }

    // MARK: - scenePreviewImagesUpdated

    func test_scenePreviewImagesUpdated_revision증가() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        await store.send(.scenePreviewImagesUpdated) {
            $0.previewRevision &+= 1
        }
    }

    func test_scenePreviewImagesUpdated_여러번호출_누적증가() async {
        let store = TestStore(
            initialState: UniverseFeature.State()
        ) {
            UniverseFeature()
        }

        await store.send(.scenePreviewImagesUpdated) {
            $0.previewRevision = 1
        }
        await store.send(.scenePreviewImagesUpdated) {
            $0.previewRevision = 2
        }
        await store.send(.scenePreviewImagesUpdated) {
            $0.previewRevision = 3
        }
    }
}
