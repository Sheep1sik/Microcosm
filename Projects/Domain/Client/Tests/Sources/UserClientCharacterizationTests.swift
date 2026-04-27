import XCTest
import ComposableArchitecture
@testable import DomainClient

// S2 리팩토링 전후로 UserClient 공개 표면을 고정.
// 9개 closure 구조 + UserProfile 기본 init 이 Feature 전반에서 의존되므로
// 3-way split 이후에도 동일 시그니처가 유지되어야 한다.
final class UserClientCharacterizationTests: XCTestCase {

    func test_UserProfile_기본_init_모든_필드_기본값_있음() {
        // 기본 init 인자 없이도 생성 가능해야 한다(Optional 닉네임 처리 포함).
        let profile = UserProfile()
        XCTAssertEqual(profile.displayName, "")
        XCTAssertEqual(profile.email, "")
        XCTAssertNil(profile.nickname)
        XCTAssertFalse(profile.hasCompletedOnboarding)
        XCTAssertFalse(profile.hasSeenConstellationGuide)
        XCTAssertFalse(profile.hasSetNickname)
    }

    func test_UserProfile_hasSetNickname_정의() {
        // 공백/빈 문자열 닉네임은 "설정되지 않음" 으로 간주되어야 한다.
        XCTAssertFalse(UserProfile(nickname: nil).hasSetNickname)
        XCTAssertFalse(UserProfile(nickname: "").hasSetNickname)
        XCTAssertTrue(UserProfile(nickname: "bob").hasSetNickname)
    }

    func test_UserClient_10개_closure_init_컴파일() {
        let client = UserClient(
            observe: { _ in AsyncStream { $0.finish() } },
            createIfNeeded: { _ in },
            setNickname: { _, _ in },
            checkNickname: { _ in false },
            updateDisplayName: { _, _ in },
            updateEmail: { _, _ in },
            markOnboardingCompleted: { _ in },
            resetOnboarding: { _ in },
            markConstellationGuideSeen: { _ in },
            deleteAllData: { _ in }
        )
        _ = client.observe("uid")
    }

    func test_DependencyValues_userClient_접근자_존재() {
        let _: WritableKeyPath<DependencyValues, UserClient> = \.userClient
    }
}
