import Foundation
import ComposableArchitecture
import DomainEntity

public struct UserProfile: Equatable {
    public var displayName: String
    public var email: String
    public var nickname: String?
    public var hasCompletedOnboarding: Bool
    public var hasSeenConstellationGuide: Bool

    public var hasSetNickname: Bool { nickname != nil && !(nickname?.isEmpty ?? true) }

    public init(
        displayName: String = "",
        email: String = "",
        nickname: String? = nil,
        hasCompletedOnboarding: Bool = false,
        hasSeenConstellationGuide: Bool = false
    ) {
        self.displayName = displayName
        self.email = email
        self.nickname = nickname
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasSeenConstellationGuide = hasSeenConstellationGuide
    }
}

public enum UserClientError: LocalizedError, Equatable {
    case nicknameTaken
    case nicknameInvalid

    public var errorDescription: String? {
        switch self {
        case .nicknameTaken: return "이미 사용 중인 닉네임이에요"
        case .nicknameInvalid: return "사용할 수 없는 닉네임이에요"
        }
    }
}

/// 닉네임 정규화: 양 끝 공백 제거 + 소문자 + 유니코드 정규화.
/// `setNickname` / `checkNickname` 양쪽이 동일 기준으로 비교/저장하기 위한 단일 진입점.
public func normalizeNickname(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines)
       .lowercased()
       .precomposedStringWithCanonicalMapping
}

public struct UserClient {
    public var observe: (String) -> AsyncStream<UserProfile>
    public var createIfNeeded: (String) async throws -> Void
    public var setNickname: (String, String) async throws -> Void
    public var checkNickname: (String) async throws -> Bool
    public var updateDisplayName: (String, String) async throws -> Void
    public var updateEmail: (String, String) async throws -> Void
    public var markOnboardingCompleted: (String) async throws -> Void
    public var resetOnboarding: (String) async throws -> Void
    public var markConstellationGuideSeen: (String) async throws -> Void

    public init(
        observe: @escaping (String) -> AsyncStream<UserProfile>,
        createIfNeeded: @escaping (String) async throws -> Void,
        setNickname: @escaping (String, String) async throws -> Void,
        checkNickname: @escaping (String) async throws -> Bool,
        updateDisplayName: @escaping (String, String) async throws -> Void,
        updateEmail: @escaping (String, String) async throws -> Void,
        markOnboardingCompleted: @escaping (String) async throws -> Void,
        resetOnboarding: @escaping (String) async throws -> Void,
        markConstellationGuideSeen: @escaping (String) async throws -> Void
    ) {
        self.observe = observe
        self.createIfNeeded = createIfNeeded
        self.setNickname = setNickname
        self.checkNickname = checkNickname
        self.updateDisplayName = updateDisplayName
        self.updateEmail = updateEmail
        self.markOnboardingCompleted = markOnboardingCompleted
        self.resetOnboarding = resetOnboarding
        self.markConstellationGuideSeen = markConstellationGuideSeen
    }
}

extension DependencyValues {
    public var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
