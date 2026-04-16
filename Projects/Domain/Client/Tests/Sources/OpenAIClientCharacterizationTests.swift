import XCTest
import ComposableArchitecture
import DomainEntity
@testable import DomainClient

// S2 리팩토링 전후로 OpenAIClient 공개 표면을 고정.
// analyzeColor/analyzeEmotion 두 async closure 구조는 Record 생성 파이프라인이 의존하므로
// 3-way split 이후에도 동일 init 시그니처가 유지되어야 한다.
final class OpenAIClientCharacterizationTests: XCTestCase {

    func test_init_2개_async_closure_프로퍼티_노출() {
        let client = OpenAIClient(
            analyzeColor: { _ in .fallback },
            analyzeEmotion: { _ in .fallback }
        )
        XCTAssertNotNil(client.analyzeColor)
        XCTAssertNotNil(client.analyzeEmotion)
    }

    func test_testValue_기본값_존재() {
        let _: OpenAIClient = OpenAIClient.testValue
    }

    func test_DependencyValues_openAIClient_접근자_존재() {
        let _: WritableKeyPath<DependencyValues, OpenAIClient> = \.openAIClient
    }
}
