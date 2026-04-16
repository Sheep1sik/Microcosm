import Foundation
import UIKit
import ComposableArchitecture
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

extension AuthClient: DependencyKey {
    public static let liveValue: AuthClient = {
        // Apple Sign-In nonce 상태 — handleAppleSignIn 에서 검증을 위해 prepare 와 분리된 호출 사이에 보관해야 한다.
        final class NonceHolder: @unchecked Sendable {
            private let lock = NSLock()
            private var _currentNonce: String?
            var currentNonce: String? {
                get { lock.withLock { _currentNonce } }
                set { lock.withLock { _currentNonce = newValue } }
            }
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
                nonceHolder.currentNonce = nil
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
            },
            clearLocalData: {
                let defaults = UserDefaults.standard
                let preserveKey = "com.microcosm.hasCompletedInitialInstallCleanup"
                let preserved = defaults.bool(forKey: preserveKey)
                let allKeys = defaults.dictionaryRepresentation().keys
                for key in allKeys where key.hasPrefix("galaxyPosition_")
                    || key.hasPrefix("galaxyProperties_")
                    || key == "hasSeenConstellationGuide"
                {
                    defaults.removeObject(forKey: key)
                }
                if preserved {
                    defaults.set(true, forKey: preserveKey)
                }
            }
        )
    }()
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
