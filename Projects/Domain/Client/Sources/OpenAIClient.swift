import Foundation
import ComposableArchitecture
import DomainEntity

public enum OpenAIError: LocalizedError, Equatable {
    case apiKeyNotConfigured
    case httpError(statusCode: Int)
    case malformedResponse
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured: return "OpenAI API 키가 설정되지 않았어요"
        case .httpError(let code): return "OpenAI 요청이 실패했어요 (HTTP \(code))"
        case .malformedResponse: return "OpenAI 응답 형식이 올바르지 않아요"
        case .decodingFailed: return "OpenAI 응답을 해석하지 못했어요"
        }
    }
}

public struct OpenAIClient {
    public var analyzeColor: (String) async throws -> RecordColor
    public var analyzeEmotion: (String) async throws -> StarVisualProfile

    public init(
        analyzeColor: @escaping (String) async throws -> RecordColor,
        analyzeEmotion: @escaping (String) async throws -> StarVisualProfile
    ) {
        self.analyzeColor = analyzeColor
        self.analyzeEmotion = analyzeEmotion
    }
}

extension DependencyValues {
    public var openAIClient: OpenAIClient {
        get { self[OpenAIClient.self] }
        set { self[OpenAIClient.self] = newValue }
    }
}
