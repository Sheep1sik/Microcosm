import XCTest
import ComposableArchitecture
import DomainEntity
@testable import DomainClient

// S2 리팩토링 전후로 RecordClient 공개 표면을 고정.
// observe/addRecord 두 클로저 구조는 Universe/Constellation Feature 가 의존하므로
// 3-way split 이후에도 동일 init 시그니처가 유지되어야 한다.
final class RecordClientCharacterizationTests: XCTestCase {

    func test_init_2개_클로저_프로퍼티_노출() {
        let client = RecordClient(
            observe: { _ in AsyncStream { $0.finish() } },
            addRecord: { _, _ in }
        )
        _ = client.observe("uid")
    }

    func test_testValue_기본값_존재() {
        let _: RecordClient = RecordClient.testValue
    }

    func test_DependencyValues_recordClient_접근자_존재() {
        let _: WritableKeyPath<DependencyValues, RecordClient> = \.recordClient
    }
}
