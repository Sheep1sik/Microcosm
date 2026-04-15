import XCTest
import ComposableArchitecture
import FirebaseAuth
@testable import DomainClient

// S2 리팩토링(AuthClient 프로토콜/Live/Test 3-way split) 전후로
// AuthClient 의 공개 표면이 깨지지 않음을 고정하는 안전망.
// init 시그니처, testValue 구성, DependencyValues 접근자를 잠근다.
final class AuthClientCharacterizationTests: XCTestCase {

    func test_init_공개_클로저_프로퍼티_모두_노출된다() {
        // 각 closure 를 대체 가능해야 한다(3-way split 이후에도 동일 init 시그니처 유지 확인).
        let client = AuthClient(
            observeAuthState: { AsyncStream { $0.finish() } },
            signInWithGoogle: {},
            prepareAppleSignIn: { "nonce" },
            handleAppleSignIn: { _ in },
            signOut: {},
            deleteAccount: {},
            currentUser: { nil }
        )
        XCTAssertEqual(client.prepareAppleSignIn(), "nonce")
        XCTAssertNil(client.currentUser())
    }

    func test_testValue_기본값은_unimplemented() {
        // 기본 testValue 는 호출 시 테스트 실패를 유발해야 한다.
        // 여기서는 존재 자체와 타입만 고정한다(실제 호출 시 XCTFail 가 발생).
        let _: AuthClient = AuthClient.testValue
    }

    func test_DependencyValues_authClient_접근자_존재() {
        // 접근자 이름이 바뀌면 전체 Feature 가 깨지므로 타입 레벨로 잠근다.
        let _: WritableKeyPath<DependencyValues, AuthClient> = \.authClient
    }
}
