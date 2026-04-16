import Foundation
import ComposableArchitecture
import FirebaseAuth
import AuthenticationServices

public struct AuthClient {
    public var observeAuthState: () -> AsyncStream<FirebaseAuth.User?>
    public var signInWithGoogle: () async throws -> Void
    public var prepareAppleSignIn: () -> String
    public var handleAppleSignIn: (ASAuthorization) async throws -> Void
    public var signOut: () throws -> Void
    public var deleteAccount: () async throws -> Void
    public var currentUser: () -> FirebaseAuth.User?
    public var clearLocalData: () -> Void

    public init(
        observeAuthState: @escaping () -> AsyncStream<FirebaseAuth.User?>,
        signInWithGoogle: @escaping () async throws -> Void,
        prepareAppleSignIn: @escaping () -> String,
        handleAppleSignIn: @escaping (ASAuthorization) async throws -> Void,
        signOut: @escaping () throws -> Void,
        deleteAccount: @escaping () async throws -> Void,
        currentUser: @escaping () -> FirebaseAuth.User?,
        clearLocalData: @escaping () -> Void
    ) {
        self.observeAuthState = observeAuthState
        self.signInWithGoogle = signInWithGoogle
        self.prepareAppleSignIn = prepareAppleSignIn
        self.handleAppleSignIn = handleAppleSignIn
        self.signOut = signOut
        self.deleteAccount = deleteAccount
        self.currentUser = currentUser
        self.clearLocalData = clearLocalData
    }
}

extension DependencyValues {
    public var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

public enum AuthError: LocalizedError {
    case noRootViewController
    case missingToken

    public var errorDescription: String? {
        switch self {
        case .noRootViewController: return "화면을 찾을 수 없습니다"
        case .missingToken: return "인증 토큰을 가져올 수 없습니다"
        }
    }
}
