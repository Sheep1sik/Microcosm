import XCTest
import ComposableArchitecture
@testable import FeatureUniverse
@testable import FeatureOnboarding
import DomainEntity
import FeatureNickname

@MainActor
final class UniverseFeatureOnboardingTests: XCTestCase {

    // MARK: - checkOnboarding (포워딩 통합 테스트)

    func test_checkOnboarding_신규유저_welcomeStep으로_설정() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboarding: OnboardingFeature.State(
                    hasReceivedInitialRecords: true,
                    hasReceivedInitialProfile: true
                )
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboarding(.check)) {
            $0.onboarding.step = .welcome
        }
    }

    func test_checkOnboarding_이미완료_상태변경없음() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboarding: OnboardingFeature.State(
                    hasCompleted: true,
                    hasReceivedInitialRecords: true,
                    hasReceivedInitialProfile: true
                )
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboarding(.check))
    }

    func test_checkOnboarding_기록존재_온보딩완료처리() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboarding: OnboardingFeature.State(
                    hasReceivedInitialRecords: true,
                    hasReceivedInitialProfile: true,
                    hasExistingRecords: true
                )
            )
        ) {
            UniverseFeature()
        }

        await store.send(.onboarding(.check)) {
            $0.onboarding.hasCompleted = true
        }
    }

    // MARK: - Race Condition (records → onboarding 포워딩)

    func test_recordsUpdated_records미도착_보류후_records도착시_welcome으로() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboarding: OnboardingFeature.State(
                    hasReceivedInitialProfile: true,
                    pendingCheck: true
                )
            )
        ) {
            UniverseFeature()
        }

        // records observer가 빈 배열을 처음 yield → 포워딩 → 보류된 check 자동 리졸브
        await store.send(.recordsUpdated([]))
        await store.receive(\.onboarding.recordsReceived) {
            $0.onboarding.hasReceivedInitialRecords = true
            $0.onboarding.hasExistingRecords = false
            $0.onboarding.pendingCheck = false
        }
        await store.receive(\.onboarding.check) {
            $0.onboarding.step = .welcome
        }
    }

    // MARK: - Scene 콜백 → 온보딩 포워딩

    func test_sceneGalaxyBirthCompleted_galaxyBirthIntro일때_monthlyGalaxyGuide로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboarding: OnboardingFeature.State(step: .galaxyBirthIntro)
            )
        ) {
            UniverseFeature()
        }

        await store.send(.sceneGalaxyBirthCompleted)
        await store.receive(\.onboarding.galaxyBirthCompleted) {
            $0.onboarding.step = .monthlyGalaxyGuide
        }
    }

    func test_sceneDidEnterGalaxyDetail_tapGalaxyPrompt일때_createStarPrompt로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboarding: OnboardingFeature.State(step: .tapGalaxyPrompt)
            )
        ) {
            UniverseFeature()
        }

        await store.send(.sceneDidEnterGalaxyDetail(key: "2026-03", records: [])) {
            $0.isInGalaxyDetail = true
            $0.currentYearMonth = "2026-03"
            $0.currentDetailRecords = []
        }
        await store.receive(\.onboarding.enteredGalaxyDetail) {
            $0.onboarding.step = .createStarPrompt
        }
    }

    // MARK: - Record Panel → 온보딩 포워딩

    func test_profileAnalyzed_createStarPrompt일때_closingMessage로_전환() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboarding: OnboardingFeature.State(step: .createStarPrompt)
            )
        ) {
            UniverseFeature()
        }

        await store.send(.profileAnalyzed(.fallback)) {
            $0.analyzedProfile = .fallback
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
            $0.pendingStarCreation = UniverseFeature.State.PendingStarCreation(
                content: "",
                starName: "",
                profile: .fallback,
                isOnboardingRecord: true
            )
        }
        await store.receive(\.onboarding.starCreated) {
            $0.onboarding.step = .closingMessage
        }
    }

    // MARK: - 전체 온보딩 플로우 (순차 검증)

    func test_전체_온보딩_플로우_순차_진행() async {
        let store = TestStore(
            initialState: UniverseFeature.State(
                onboarding: OnboardingFeature.State(
                    hasReceivedInitialRecords: true,
                    hasReceivedInitialProfile: true
                )
            )
        ) {
            UniverseFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
        }
        store.exhaustivity = .off

        // 1. 온보딩 시작 → welcome
        await store.send(.onboarding(.check)) {
            $0.onboarding.step = .welcome
        }

        // 2. welcome → nicknameInput
        await store.send(.onboarding(.advanceFromWelcome)) {
            $0.onboarding.step = .nicknameInput
        }

        // 3. 닉네임 저장 완료 → galaxyBirthIntro
        await store.send(.onboarding(.nickname(.delegate(.nicknameSet)))) {
            $0.onboarding.userDisplayName = ""
            $0.onboarding.step = .galaxyBirthIntro
        }

        // 4. 은하 탄생 애니메이션 완료 → monthlyGalaxyGuide
        await store.send(.sceneGalaxyBirthCompleted)
        await store.receive(\.onboarding.galaxyBirthCompleted) {
            $0.onboarding.step = .monthlyGalaxyGuide
        }

        // 5. 가이드 탭 → tapGalaxyPrompt
        await store.send(.onboarding(.advanceFromGuide)) {
            $0.onboarding.step = .tapGalaxyPrompt
        }

        // 6. 은하 탭 (galaxyDetail 진입) → createStarPrompt
        await store.send(.sceneDidEnterGalaxyDetail(key: "2026-03", records: [])) {
            $0.isInGalaxyDetail = true
            $0.currentYearMonth = "2026-03"
            $0.currentDetailRecords = []
        }
        await store.receive(\.onboarding.enteredGalaxyDetail) {
            $0.onboarding.step = .createStarPrompt
        }

        // 7. 별 생성 후 감정분석 완료 → closingMessage
        await store.send(.profileAnalyzed(.fallback)) {
            $0.analyzedProfile = .fallback
            $0.isAnalyzingColor = false
            $0.showRecordPanel = false
        }
        await store.receive(\.onboarding.starCreated) {
            $0.onboarding.step = .closingMessage
        }

        // 8. 온보딩 완료
        await store.send(.onboarding(.complete)) {
            $0.onboarding.step = .completed
            $0.onboarding.hasCompleted = true
        }
    }
}
