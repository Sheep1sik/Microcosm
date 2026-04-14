import XCTest
@testable import DomainClient

final class OpenAIErrorTests: XCTestCase {

    // analyzeColor/analyzeEmotion이 throw하는 OpenAIError의
    // 사용자 표시 메시지를 한국어로 일관되게 제공하는지 검증.

    func test_apiKeyNotConfigured_사용자메시지() {
        XCTAssertEqual(
            OpenAIError.apiKeyNotConfigured.errorDescription,
            "OpenAI API 키가 설정되지 않았어요"
        )
    }

    func test_httpError_상태코드_포함() {
        XCTAssertEqual(
            OpenAIError.httpError(statusCode: 401).errorDescription,
            "OpenAI 요청이 실패했어요 (HTTP 401)"
        )
        XCTAssertEqual(
            OpenAIError.httpError(statusCode: 500).errorDescription,
            "OpenAI 요청이 실패했어요 (HTTP 500)"
        )
    }

    func test_malformedResponse_사용자메시지() {
        XCTAssertEqual(
            OpenAIError.malformedResponse.errorDescription,
            "OpenAI 응답 형식이 올바르지 않아요"
        )
    }

    func test_decodingFailed_사용자메시지() {
        XCTAssertEqual(
            OpenAIError.decodingFailed.errorDescription,
            "OpenAI 응답을 해석하지 못했어요"
        )
    }

    func test_Equatable_같은케이스_같은상태코드_동등() {
        XCTAssertEqual(OpenAIError.apiKeyNotConfigured, .apiKeyNotConfigured)
        XCTAssertEqual(
            OpenAIError.httpError(statusCode: 401),
            OpenAIError.httpError(statusCode: 401)
        )
        XCTAssertNotEqual(
            OpenAIError.httpError(statusCode: 401),
            OpenAIError.httpError(statusCode: 500)
        )
    }
}
