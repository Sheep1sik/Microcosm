import XCTest
import ComposableArchitecture
@testable import FeatureConstellation
import DomainEntity

@MainActor
final class ConstellationFeatureSceneCallbacksTests: XCTestCase {

    // MARK: - sceneDidEnterConstellationDetail

    func test_sceneDidEnterConstellationDetail_상세진입_상태반영() async {
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }

        await store.send(.sceneDidEnterConstellationDetail(id: "ORI")) {
            $0.isInConstellationDetail = true
            $0.selectedConstellationId = "ORI"
        }
    }

    func test_sceneDidEnterConstellationDetail_가이드tapConstellation일때_tapStar로_전환() async {
        var state = ConstellationFeature.State()
        state.guideStep = .tapConstellation
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        }

        await store.send(.sceneDidEnterConstellationDetail(id: "ORI")) {
            $0.isInConstellationDetail = true
            $0.selectedConstellationId = "ORI"
            $0.guideStep = .tapStar
        }
    }

    // MARK: - sceneDidExitConstellationDetail

    func test_sceneDidExitConstellationDetail_상세상태_전체초기화() async {
        var state = ConstellationFeature.State(
            selectedConstellationId: "ORI",
            selectedStarIndex: 2,
            isInConstellationDetail: true,
            showGoalPanel: true,
            isEditingGoal: true
        )
        state.guideStep = .tapStar
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        }

        await store.send(.sceneDidExitConstellationDetail) {
            $0.isInConstellationDetail = false
            $0.selectedConstellationId = nil
            $0.selectedStarIndex = nil
            $0.showGoalPanel = false
            $0.isEditingGoal = false
        }
    }

    // MARK: - sceneDidTapStar

    func test_sceneDidTapStar_별선택_패널오픈() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                selectedConstellationId: "ORI"
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.sceneDidTapStar(constellationId: "ORI", starIndex: 3)) {
            $0.selectedConstellationId = "ORI"
            $0.selectedStarIndex = 3
            $0.showGoalPanel = true
            $0.isEditingGoal = false
        }
    }

    func test_sceneDidTapStar_가이드tapStar일때_registerGoal로_전환() async {
        var state = ConstellationFeature.State(
            selectedConstellationId: "ORI"
        )
        state.guideStep = .tapStar
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        }

        await store.send(.sceneDidTapStar(constellationId: "ORI", starIndex: 1)) {
            $0.selectedConstellationId = "ORI"
            $0.selectedStarIndex = 1
            $0.showGoalPanel = true
            $0.isEditingGoal = false
            $0.guideStep = .registerGoal
        }
    }

    // MARK: - sceneDidTapEmptyArea

    func test_sceneDidTapEmptyArea_패널열려있고편집아님_패널닫기() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                selectedStarIndex: 2,
                showGoalPanel: true,
                isEditingGoal: false
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.sceneDidTapEmptyArea) {
            $0.showGoalPanel = false
            $0.selectedStarIndex = nil
        }
    }

    func test_sceneDidTapEmptyArea_편집중이면_패널유지() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                selectedStarIndex: 2,
                showGoalPanel: true,
                isEditingGoal: true
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.sceneDidTapEmptyArea)
    }

    func test_sceneDidTapEmptyArea_패널닫힌상태_무시() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                showGoalPanel: false
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.sceneDidTapEmptyArea)
    }
}
