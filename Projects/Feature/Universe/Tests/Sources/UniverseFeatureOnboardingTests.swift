import XCTest
import ComposableArchitecture
@testable import FeatureUniverse
import DomainEntity
import FeatureNickname

@MainActor
final class UniverseFeatureOnboardingTests: XCTestCase {

    // MARK: - checkOnboarding

    func test_checkOnboarding_신규유저_welcomeStep으로_설정() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasReceivedInitialRecords: true,
                hasReceivedInitialProfile: true
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding) {
            $0.onboardingStep = .welcome
        }
    }

    func test_checkOnboarding_이미완료_상태변경없음() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: true,
                hasReceivedInitialRecords: true,
                hasReceivedInitialProfile: true
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
                hasReceivedInitialRecords: true,
                hasReceivedInitialProfile: true,
                allRecords: [Record(content: "테스트 기록")]
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding) {
            $0.hasCompletedOnboarding = true
        }
    }

    // MARK: - Race Condition (M7)

    func test_checkOnboarding_records미도착_보류후_records도착시_welcome으로() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasReceivedInitialRecords: false,
                hasReceivedInitialProfile: true
            )
        ) {
            UniverseFeature()
        }

        // View에서 scene setup 시 즉시 호출되는 checkOnboarding은 보류됨
        await store.send(.checkOnboarding) {
            $0.pendingOnboardingCheck = true
        }

        // records observer가 빈 배열을 처음 yield → 보류된 checkOnboarding 자동 리졸브
        await store.send(.recordsUpdated([])) {
            $0.hasReceivedInitialRecords = true
            $0.pendingOnboardingCheck = false
        }

        await store.receive(\.checkOnboarding) {
            $0.onboardingStep = .welcome
        }
    }

    func test_checkOnboarding_records미도착_보류후_기록존재면_온보딩건너뜀() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasReceivedInitialRecords: false,
                hasReceivedInitialProfile: true
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding) {
            $0.pendingOnboardingCheck = true
        }

        let record = Record(content: "기존 기록")
        await store.send(.recordsUpdated([record])) {
            $0.hasReceivedInitialRecords = true
            $0.pendingOnboardingCheck = false
            $0.allRecords = [record]
        }

        await store.receive(\.checkOnboarding) {
            $0.hasCompletedOnboarding = true
        }
    }

    // MARK: - Race Condition (profile 지연) — 기존 유저가 재시작 시 다시 welcome 로
    // 진입해 닉네임을 덮어쓰는 회귀 방지용 테스트.

    func test_checkOnboarding_profile미도착_보류후_profile도착시_완료유저는_welcome생략() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasReceivedInitialRecords: true,
                hasReceivedInitialProfile: false
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding) {
            $0.pendingOnboardingCheck = true
        }

        // profile observer 가 완료 플래그를 싣고 처음 yield. reducer 가 외부에서 직접
        // hasCompletedOnboarding 을 true 로 주입받는 MainTab 경로를 시뮬레이션.
        await store.send(.binding(.set(\.hasCompletedOnboarding, true))) {
            $0.hasCompletedOnboarding = true
        }
        await store.send(.profileReceived) {
            $0.hasReceivedInitialProfile = true
            $0.pendingOnboardingCheck = false
        }

        await store.receive(\.checkOnboarding)
    }

    func test_checkOnboarding_records와profile_모두미도착_둘다도착해야_welcome() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasReceivedInitialRecords: false,
                hasReceivedInitialProfile: false
            )
        ) {
            UniverseFeature()
        }

        await store.send(.checkOnboarding) {
            $0.pendingOnboardingCheck = true
        }

        // records 먼저 도착 → drain 시도 → checkOnboarding 재발송 → guard 에서 profile 미도착
        // 으로 다시 pending
        await store.send(.recordsUpdated([])) {
            $0.hasReceivedInitialRecords = true
            $0.pendingOnboardingCheck = false
        }
        await store.receive(\.checkOnboarding) {
            $0.pendingOnboardingCheck = true
        }

        // profile 도 도착 → drain → welcome 진입
        await store.send(.profileReceived) {
            $0.hasReceivedInitialProfile = true
            $0.pendingOnboardingCheck = false
        }
        await store.receive(\.checkOnboarding) {
            $0.onboardingStep = .welcome
        }
    }

    func test_recordsUpdated_보류중이아니면_체크자동실행안함() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                hasCompletedOnboarding: false,
                hasReceivedInitialRecords: false,
                pendingOnboardingCheck: false
            )
        ) {
            UniverseFeature()
        }

        // View에서 checkOnboarding 미호출 → 보류 없음 → records 도착해도 자동 실행 없음
        await store.send(.recordsUpdated([])) {
            $0.hasReceivedInitialRecords = true
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

    func test_onboardingNicknameSaveCompleted_galaxyBirthIntro로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboardingStep: .nicknameInput,
                onboardingNickname: NicknameFeature.State(
                    nickname: "테스트유저",
                    isSaving: true
                )
            )
        ) {
            UniverseFeature()
        }

        // NicknameFeature.saveCompleted → delegate(.nicknameSet) → Universe 가 받아 step 전환
        await store.send(.onboardingNickname(.saveCompleted)) {
            $0.onboardingNickname.isSaving = false
        }
        await store.receive(\.onboardingNickname.delegate.nicknameSet) {
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
                onboardingStep: .closingMessage
            )
        ) {
            UniverseFeature()
        } withDependencies: {
            // authClient.currentUser()?.uid == nil 이면 markOnboardingCompleted 부작용은
            // guard let 에서 조기 종료한다. 여기서는 reducer state 전이만 검증한다.
            $0.authClient.currentUser = { nil }
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
        } withDependencies: {
            $0.authClient.currentUser = { nil }
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
                hasReceivedInitialRecords: true,
                hasReceivedInitialProfile: true
            )
        ) {
            UniverseFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
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

        // 3. 닉네임 저장 완료 → galaxyBirthIntro (NicknameFeature delegate 경유)
        await store.send(.onboardingNickname(.delegate(.nicknameSet))) {
            $0.userDisplayName = ""
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
