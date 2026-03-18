import Foundation
import ComposableArchitecture
import DomainEntity
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

public struct AuthClient {
    public var observeAuthState: () -> AsyncStream<FirebaseAuth.User?>
    public var signInWithGoogle: () async throws -> Void
    public var prepareAppleSignIn: () -> String
    public var handleAppleSignIn: (ASAuthorization) async throws -> Void
    public var signOut: () throws -> Void
    public var deleteAccount: () async throws -> Void
    public var currentUser: () -> FirebaseAuth.User?

    public init(
        observeAuthState: @escaping () -> AsyncStream<FirebaseAuth.User?>,
        signInWithGoogle: @escaping () async throws -> Void,
        prepareAppleSignIn: @escaping () -> String,
        handleAppleSignIn: @escaping (ASAuthorization) async throws -> Void,
        signOut: @escaping () throws -> Void,
        deleteAccount: @escaping () async throws -> Void,
        currentUser: @escaping () -> FirebaseAuth.User?
    ) {
        self.observeAuthState = observeAuthState
        self.signInWithGoogle = signInWithGoogle
        self.prepareAppleSignIn = prepareAppleSignIn
        self.handleAppleSignIn = handleAppleSignIn
        self.signOut = signOut
        self.deleteAccount = deleteAccount
        self.currentUser = currentUser
    }
}

extension AuthClient: DependencyKey {
    public static let liveValue: AuthClient = {
        // Apple Sign-In nonce 상태
        final class NonceHolder: @unchecked Sendable {
            var currentNonce: String?
        }
        let nonceHolder = NonceHolder()

        return AuthClient(
            observeAuthState: {
                AsyncStream { continuation in
                    let handle = Auth.auth().addStateDidChangeListener { _, user in
                        continuation.yield(user)
                    }
                    continuation.onTermination = { _ in
                        Auth.auth().removeStateDidChangeListener(handle)
                    }
                }
            },
            signInWithGoogle: {
                let result = try await Task { @MainActor in
                    guard let rootVC = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else {
                        throw AuthError.noRootViewController
                    }
                    return try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                }.value
                guard let idToken = result.user.idToken?.tokenString else {
                    throw AuthError.missingToken
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                try await Auth.auth().signIn(with: credential)
            },
            prepareAppleSignIn: {
                let nonce = randomNonceString()
                nonceHolder.currentNonce = nonce
                return sha256(nonce)
            },
            handleAppleSignIn: { authorization in
                guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let appleIDToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: appleIDToken, encoding: .utf8),
                      let nonce = nonceHolder.currentNonce else {
                    throw AuthError.missingToken
                }
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                try await Auth.auth().signIn(with: credential)
            },
            signOut: {
                try Auth.auth().signOut()
            },
            deleteAccount: {
                guard let user = Auth.auth().currentUser else { return }
                try await user.delete()
            },
            currentUser: {
                Auth.auth().currentUser
            }
        )
    }()
}

extension DependencyValues {
    public var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

// MARK: - Helpers

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

private func randomNonceString(length: Int = 32) -> String {
    var randomBytes = [UInt8](repeating: 0, count: length)
    _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    return String(randomBytes.map { charset[Int($0) % charset.count] })
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}
