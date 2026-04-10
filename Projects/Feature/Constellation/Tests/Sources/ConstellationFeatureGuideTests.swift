import XCTest
import ComposableArchitecture
@testable import FeatureConstellation

@MainActor
final class ConstellationFeatureGuideTests: XCTestCase {

    private let legacyKey = "hasSeenConstellationGuide"

    override func setUp() {
        super.setUp()
        // 레거시 UserDefaults 마이그레이션 경로를 깔끔하게 하기 위해 항상 제거.
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: legacyKey)
        super.tearDown()
    }

    // MARK: - onAppear → checkGuide

    func test_onAppear_checkGuide액션_방출() async {
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }

        await store.send(.onAppear)
        await store.receive(\.checkGuide) {
            $0.showGuide = true
            $0.guideStep = .welcome
        }
    }

    // MARK: - checkGuide

    func test_checkGuide_처음본다면_welcome단계로_시작() async {
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }

        await store.send(.checkGuide) {
            $0.showGuide = true
            $0.guideStep = .welcome
        }
    }

    func test_checkGuide_hasSeenConstellationGuide_true_가이드표시없음() async {
        var state = ConstellationFeature.State()
        state.hasSeenConstellationGuide = true
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        }

        await store.send(.checkGuide)
    }

    func test_checkGuide_레거시UserDefaults_있으면_Firestore로_마이그레이션후_표시없음() async {
        // 이전 버전에서 가이드를 완료했던 사용자(레거시 UserDefaults 기록 존재).
        UserDefaults.standard.set(true, forKey: legacyKey)

        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        } withDependencies: {
            // authClient.currentUser == nil 이면 Firestore 마이그레이션 effect 가 guard 로 빠져 성공.
            $0.authClient.currentUser = { nil }
        }
        store.exhaustivity = .off

        await store.send(.checkGuide) {
            $0.hasSeenConstellationGuide = true
        }
    }

    // MARK: - advanceGuide

    func test_advanceGuide_welcome_tapConstellation으로_전환() async {
        var state = ConstellationFeature.State()
        state.guideStep = .welcome
        state.showGuide = true
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        }

        await store.send(.advanceGuide) {
            $0.guideStep = .tapConstellation
        }
    }

    func test_advanceGuide_closing_가이드종료_플래그설정() async {
        var state = ConstellationFeature.State()
        state.guideStep = .closing
        state.showGuide = true
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
        }
        store.exhaustivity = .off

        await store.send(.advanceGuide) {
            $0.showGuide = false
            $0.guideStep = nil
            $0.hasSeenConstellationGuide = true
        }
    }

    func test_advanceGuide_tapConstellation_tapStar_registerGoal단계는_상태불변() async {
        for step in [ConstellationFeature.State.GuideStep.tapConstellation,
                     .tapStar,
                     .registerGoal] {
            var state = ConstellationFeature.State()
            state.guideStep = step
            state.showGuide = true
            let store = TestStore(
                initialState: state
            ) {
                ConstellationFeature()
            }

            // 유저 직접 조작(scene 콜백/저장)을 통해서만 진행되는 단계 → advanceGuide 무시.
            await store.send(.advanceGuide)
        }
    }

    func test_advanceGuide_guideStep_nil_showGuide_false로_전환() async {
        var state = ConstellationFeature.State()
        state.showGuide = true
        state.guideStep = nil
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        }

        await store.send(.advanceGuide) {
            $0.showGuide = false
        }
    }

    // MARK: - dismissGuide

    func test_dismissGuide_가이드종료_플래그설정() async {
        var state = ConstellationFeature.State()
        state.showGuide = true
        state.guideStep = .tapStar
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
        }
        store.exhaustivity = .off

        await store.send(.dismissGuide) {
            $0.showGuide = false
            $0.guideStep = nil
            $0.hasSeenConstellationGuide = true
        }
    }
}
