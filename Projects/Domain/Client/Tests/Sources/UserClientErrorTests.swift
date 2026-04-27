import XCTest
@testable import DomainClient

final class UserClientErrorTests: XCTestCase {

    func test_nicknameTaken_사용자메시지() {
        XCTAssertEqual(
            UserClientError.nicknameTaken.errorDescription,
            "이미 사용 중인 닉네임이에요"
        )
    }

    func test_nicknameInvalid_사용자메시지() {
        XCTAssertEqual(
            UserClientError.nicknameInvalid.errorDescription,
            "사용할 수 없는 닉네임이에요"
        )
    }

    func test_Equatable_케이스간_구분() {
        XCTAssertEqual(UserClientError.nicknameTaken, .nicknameTaken)
        XCTAssertNotEqual(UserClientError.nicknameTaken, UserClientError.nicknameInvalid)
    }
}
