import Foundation
import ComposableArchitecture

extension AuthClient: TestDependencyKey {
    public static let testValue = AuthClient(
        observeAuthState: unimplemented("\(Self.self).observeAuthState"),
        signInWithGoogle: unimplemented("\(Self.self).signInWithGoogle"),
        prepareAppleSignIn: unimplemented("\(Self.self).prepareAppleSignIn"),
        handleAppleSignIn: unimplemented("\(Self.self).handleAppleSignIn"),
        signOut: unimplemented("\(Self.self).signOut"),
        deleteAccount: unimplemented("\(Self.self).deleteAccount"),
        currentUser: unimplemented("\(Self.self).currentUser")
    )
}
