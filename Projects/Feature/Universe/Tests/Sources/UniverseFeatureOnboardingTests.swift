import XCTest
import ComposableArchitecture
@testable import FeatureUniverse
import DomainEntity

@MainActor
final class UniverseFeatureOnboardingTests: XCTestCase {

    // MARK: - checkOnboarding

    func test_checkOnboarding_신규유저_welcomeStep으로_설정() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasSetNickname: false
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding) {
            $0.onboardingStep = .welcome
        }
    }

    func test_checkOnboarding_닉네임설정완료_galaxyBirthIntro로_설정() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasSetNickname: true
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding) {
            $0.onboardingStep = .galaxyBirthIntro
        }
    }

    func test_checkOnboarding_이미완료_상태변경없음() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: true
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding)
    }

    func test_checkOnboarding_기록존재_온보딩완료처리() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                allRecords: [Record(content: "테스트 기록")]
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding) {
            $0.hasCompletedOnboarding = true
        }
    }

    // MARK: - Welcome Step 전환

    func test_onboardingAdvanceFromWelcome_nicknameInput으로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .welcome
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboardingAdvanceFromWelcome) {
            $0.onboardingStep = .nicknameInput
        }
    }

    func test_onboardingAdvanceFromWelcome_welcome이_아닐때_무시() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .nicknameInput
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboardingAdvanceFromWelcome)
    }

    // MARK: - Nickname → Galaxy Birth

    func test_onboardingNicknameSaved_galaxyBirthIntro로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .nicknameInput,
                onboardingNickname: "테스트유저",
                onboardingNicknameSaving: true
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboardingNicknameSaved) {
            $0.onboardingNicknameSaving = false
            $0.hasSetNickname = true
            $0.userDisplayName = "테스트유저"
            $0.onboardingStep = .galaxyBirthIntro
        }
    }

    // MARK: - Galaxy Birth Completed (버그 수정 핵심 테스트)

    func test_galaxyBirthCompleted_galaxyBirthIntro일때_monthlyGalaxyGuide로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .galaxyBirthIntro
            )
        ) {
            UniverseFeature()
        }

        await store.send(.sceneGalaxyBirthCompleted) {
            $0.onboardingStep = .monthlyGalaxyGuide
        }
    }

    /// 핵심: welcome 단계에서 galaxyBirthCompleted가 들어와도 상태가 변하지 않아야 한다.
    /// (기존 버그: didMove(to:)에서 delegate 설정 전에 refreshGalaxies()가 호출되어
    ///  은하가 즉시 생성되고, birth 애니메이션 완료 콜백이 welcome 단계에서 발생)
    func test_galaxyBirthCompleted_welcome단계에서_상태변경없음() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .welcome
            )
        ) {
            UniverseFeature()
        }

        await store.send(.sceneGalaxyBirthCompleted)
    }

    func test_galaxyBirthCompleted_nicknameInput단계에서_상태변경없음() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .nicknameInput
            )
        ) {
            UniverseFeature()
        }

        await store.send(.sceneGalaxyBirthCompleted)
    }

    // MARK: - Monthly Galaxy Guide → Tap Galaxy

    func test_onboardingAdvanceFromGuide_tapGalaxyPrompt로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .monthlyGalaxyGuide
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboardingAdvanceFromGuide) {
            $0.onboardingStep = .tapGalaxyPrompt
        }
    }

    func test_onboardingAdvanceFromGuide_다른단계에서_무시() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .tapGalaxyPrompt
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboardingAdvanceFromGuide)
    }

    // MARK: - Tap Galaxy → Create Star

    func test_sceneDidEnterGalaxyDetail_tapGalaxyPrompt일때_createStarPrompt로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .tapGalaxyPrompt
            )
        ) {
            UniverseFeature()
        }

        await store.send(.sceneDidEnterGalaxyDetail(key: "2026-03", records: [])) {
            $0.isInGalaxyDetail = true
            $0.currentYearMonth = "2026-03"
            $0.currentDetailRecords = []
            $0.onboardingStep = .createStarPrompt
        }
    }

    func test_sceneDidEnterGalaxyDetail_온보딩아닐때_step변경없음() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: true,
                onboardingStep: nil
            )
        ) {
            UniverseFeature()
        }

        await store.send(.sceneDidEnterGalaxyDetail(key: "2026-03", records: [])) {
            $0.isInGalaxyDetail = true
            $0.currentYearMonth = "2026-03"
            $0.currentDetailRecords = []
        }
    }

    // MARK: - Onboarding Complete

    func test_onboardingComplete_completed로_전환_및_플래그설정() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .closingMessage,
                hasSetNickname: true
            )
        ) {
            UniverseFeature()
        }
        store.exhaustivity = .off

        await store.send(.onboardingComplete) {
            $0.onboardingStep = .completed
            $0.hasCompletedOnboarding = true
        }
    }

    func test_onboardingComplete_이미completed면_무시() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: true,
                onboardingStep: .completed
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboardingComplete)
    }

    // MARK: - Skip Onboarding

    func test_skipOnboarding_즉시완료() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .welcome
            )
        ) {
            UniverseFeature()
        }
        store.exhaustivity = .off

        await store.send(.skipOnboarding) {
            $0.onboardingStep = .completed
            $0.hasCompletedOnboarding = true
        }
    }

    // MARK: - isOnboarding 계산 속성

    func test_isOnboarding_welcome일때_true() {
        let state = UniverseFeature.State(onboardingStep: .welcome)
        XCTAssertTrue(state.isOnboarding)
    }

    func test_isOnboarding_galaxyBirthIntro일때_true() {
        let state = UniverseFeature.State(onboardingStep: .galaxyBirthIntro)
        XCTAssertTrue(state.isOnboarding)
    }

    func test_isOnboarding_completed일때_false() {
        let state = UniverseFeature.State(onboardingStep: .completed)
        XCTAssertFalse(state.isOnboarding)
    }

    func test_isOnboarding_nil일때_false() {
        let state = UniverseFeature.State(onboardingStep: nil)
        XCTAssertFalse(state.isOnboarding)
    }

    // MARK: - 전체 온보딩 플로우 (순차 검증)

    func test_전체_온보딩_플로우_순차_진행() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasSetNickname: false
            )
        ) {
            UniverseFeature()
        }
        store.exhaustivity = .off

        // 1. 온보딩 시작 → welcome
        await store.send(.checkOnboarding) {
            $0.onboardingStep = .welcome
        }

        // 2. welcome → nicknameInput
        await store.send(.onboardingAdvanceFromWelcome) {
            $0.onboardingStep = .nicknameInput
        }

        // 3. 닉네임 저장 완료 → galaxyBirthIntro
        // (여기서 scene.refreshGalaxies()가 onChange로 트리거됨)
        store.send(.binding(.set(\.onboardingNickname, "테스트유저")))
        await store.send(.onboardingNicknameSaved) {
            $0.onboardingNicknameSaving = false
            $0.hasSetNickname = true
            $0.userDisplayName = "테스트유저"
            $0.onboardingStep = .galaxyBirthIntro
        }

        // 4. 은하 탄생 애니메이션 완료 → monthlyGalaxyGuide
        await store.send(.sceneGalaxyBirthCompleted) {
            $0.onboardingStep = .monthlyGalaxyGuide
        }

        // 5. 가이드 탭 → tapGalaxyPrompt
        await store.send(.onboardingAdvanceFromGuide) {
            $0.onboardingStep = .tapGalaxyPrompt
        }

        // 6. 은하 탭 (galaxyDetail 진입) → createStarPrompt
        await store.send(.sceneDidEnterGalaxyDetail(key: "2026-03", records: [])) {
            $0.isInGalaxyDetail = true
            $0.currentYearMonth = "2026-03"
            $0.currentDetailRecords = []
            $0.onboardingStep = .createStarPrompt
        }

        // 7. 별 생성 후 감정분석 완료 → closingMessage
        await store.send(.profileAnalyzed(.fallback)) {
            $0.analyzedProfile = .fallback
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
            $0.onboardingStep = .closingMessage
        }

        // 8. 온보딩 완료
        await store.send(.onboardingComplete) {
            $0.onboardingStep = .completed
            $0.hasCompletedOnboarding = true
        }
    }
}
