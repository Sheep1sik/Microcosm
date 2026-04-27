import XCTest
import ComposableArchitecture
import DomainEntity
@testable import DomainClient

// S2 리팩토링 전후로 GoalClient 공개 표면을 고정.
// observe/addGoal/updateGoal/deleteGoal 4-closure 구조는 Feature 전반에서 의존하므로
// 3-way split 이후에도 동일 init 시그니처가 유지되어야 한다.
final class GoalClientCharacterizationTests: XCTestCase {

    func test_init_4개_클로저_프로퍼티_노출() {
        let client = GoalClient(
            observe: { _ in AsyncStream { $0.finish() } },
            addGoal: { _, _ in },
            updateGoal: { _, _ in },
            deleteGoal: { _, _ in }
        )
        // observe 는 userId String 을 입력으로 받는 단일 파라미터 클로저여야 한다.
        _ = client.observe("uid")
    }

    func test_testValue_기본값_존재() {
        let _: GoalClient = GoalClient.testValue
    }

    func test_DependencyValues_goalClient_접근자_존재() {
        let _: WritableKeyPath<DependencyValues, GoalClient> = \.goalClient
    }
}
