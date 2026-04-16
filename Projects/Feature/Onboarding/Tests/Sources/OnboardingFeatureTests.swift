import XCTest
import ComposableArchitecture
@testable import FeatureOnboarding

@MainActor
final class OnboardingFeatureTests: XCTestCase {

    // MARK: - check

    func test_check_신규유저_welcome() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(
                hasReceivedInitialRecords: true,
                hasReceivedInitialProfile: true
            )
        ) {
            OnboardingFeature()
        }

        await store.send(.check) {
            $0.step = .welcome
        }
    }

    func test_check_이미완료_변경없음() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(
                hasCompleted: true,
                hasReceivedInitialRecords: true,
                hasReceivedInitialProfile: true
            )
        ) {
            OnboardingFeature()
        }

        await store.send(.check)
    }

    func test_check_기록존재_즉시완료() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(
                hasReceivedInitialRecords: true,
                hasReceivedInitialProfile: true,
                hasExistingRecords: true
            )
        ) {
            OnboardingFeature()
        }

        await store.send(.check) {
            $0.hasCompleted = true
        }
    }

    func test_check_records미도착_보류() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(
                hasReceivedInitialProfile: true
            )
        ) {
            OnboardingFeature()
        }

        await store.send(.check) {
            $0.pendingCheck = true
        }
    }

    // MARK: - recordsReceived

    func test_recordsReceived_pending이고_profile도착_drain() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(
                hasReceivedInitialProfile: true,
                pendingCheck: true
            )
        ) {
            OnboardingFeature()
        }

        await store.send(.recordsReceived(hasRecords: false)) {
            $0.hasReceivedInitialRecords = true
            $0.hasExistingRecords = false
            $0.pendingCheck = false
        }
        await store.receive(\.check) {
            $0.step = .welcome
        }
    }

    // MARK: - profileReceived

    func test_profileReceived_pending이고_records도착_drain() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(
                hasReceivedInitialRecords: true,
                pendingCheck: true
            )
        ) {
            OnboardingFeature()
        }

        await store.send(.profileReceived) {
            $0.hasReceivedInitialProfile = true
            $0.pendingCheck = false
        }
        await store.receive(\.check) {
            $0.step = .welcome
        }
    }

    // MARK: - Step Advancement

    func test_advanceFromWelcome_nicknameInput() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .welcome)
        ) {
            OnboardingFeature()
        }

        await store.send(.advanceFromWelcome) {
            $0.step = .nicknameInput
        }
    }

    func test_advanceFromGuide_tapGalaxyPrompt() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .monthlyGalaxyGuide)
        ) {
            OnboardingFeature()
        }

        await store.send(.advanceFromGuide) {
            $0.step = .tapGalaxyPrompt
        }
    }

    func test_galaxyBirthCompleted_monthlyGalaxyGuide() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .galaxyBirthIntro)
        ) {
            OnboardingFeature()
        }

        await store.send(.galaxyBirthCompleted) {
            $0.step = .monthlyGalaxyGuide
        }
    }

    func test_enteredGalaxyDetail_createStarPrompt() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .tapGalaxyPrompt)
        ) {
            OnboardingFeature()
        }

        await store.send(.enteredGalaxyDetail) {
            $0.step = .createStarPrompt
        }
    }

    func test_starCreated_closingMessage() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .createStarPrompt)
        ) {
            OnboardingFeature()
        }

        await store.send(.starCreated) {
            $0.step = .closingMessage
        }
    }

    func test_complete_서버저장() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .closingMessage)
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
        }

        await store.send(.complete) {
            $0.step = .completed
            $0.hasCompleted = true
        }
    }

    // MARK: - Guard (잘못된 단계에서의 전환 방지)

    func test_advanceFromWelcome_잘못된단계_무시() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .galaxyBirthIntro)
        ) {
            OnboardingFeature()
        }

        await store.send(.advanceFromWelcome)
    }

    func test_starCreated_잘못된단계_무시() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(step: .welcome)
        ) {
            OnboardingFeature()
        }

        await store.send(.starCreated)
    }
}
