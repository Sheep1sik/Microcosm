import XCTest
import ComposableArchitecture
import AuthenticationServices
@testable import FeatureAuth
import DomainClient

@MainActor
final class LoginFeatureTests: XCTestCase {

    // MARK: - signInFailed

    func test_signInFailed_에러상태_반영() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        }

        await store.send(.signInFailed("테스트 에러")) {
            $0.errorMessage = "테스트 에러"
            $0.showError = true
        }
    }

    // MARK: - appleSignInCompleted 실패

    func test_appleSignInCompleted_canceled는_침묵() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        }

        let canceled = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.canceled.rawValue
        )

        // 상태 변화 없음. showError / errorMessage 모두 그대로.
        await store.send(.appleSignInCompleted(.failure(canceled)))
    }

    func test_appleSignInCompleted_기타에러는_에러상태반영() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        }

        let other = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.failed.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "애플 로그인 실패"]
        )

        await store.send(.appleSignInCompleted(.failure(other))) {
            $0.errorMessage = "애플 로그인 실패"
            $0.showError = true
        }
    }

    func test_appleSignInCompleted_다른도메인에러도_에러상태반영() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        }

        let other = NSError(
            domain: "SomeOtherDomain",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "기타 실패"]
        )

        await store.send(.appleSignInCompleted(.failure(other))) {
            $0.errorMessage = "기타 실패"
            $0.showError = true
        }
    }

    // MARK: - googleSignInTapped 실패 경로

    func test_googleSignInTapped_실패시_signInFailed_dispatch() async {
        struct Boom: LocalizedError { var errorDescription: String? { "구글 실패" } }

        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        } withDependencies: {
            $0.authClient.signInWithGoogle = { throw Boom() }
        }

        await store.send(.googleSignInTapped)
        await store.receive(\.signInFailed) {
            $0.errorMessage = "구글 실패"
            $0.showError = true
        }
    }
}
