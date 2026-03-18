import ComposableArchitecture
import AuthenticationServices
import DomainClient

@Reducer
public struct LoginFeature {
    @ObservableState
    public struct State: Equatable {
        public var errorMessage: String?
        public var showError = false

        public init(
            errorMessage: String? = nil,
            showError: Bool = false
        ) {
            self.errorMessage = errorMessage
            self.showError = showError
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case googleSignInTapped
        case appleSignInRequested(ASAuthorizationAppleIDRequest)
        case appleSignInCompleted(Result<ASAuthorization, Error>)
        case signInFailed(String)
    }

    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .googleSignInTapped:
                return .run { send in
                    do {
                        try await authClient.signInWithGoogle()
                    } catch {
                        await send(.signInFailed(error.localizedDescription))
                    }
                }

            case .appleSignInRequested(let request):
                let hashedNonce = authClient.prepareAppleSignIn()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
                return .none

            case .appleSignInCompleted(.success(let authorization)):
                return .run { send in
                    do {
                        try await authClient.handleAppleSignIn(authorization)
                    } catch {
                        await send(.signInFailed(error.localizedDescription))
                    }
                }

            case .appleSignInCompleted(.failure(let error)):
                let nsError = error as NSError
                if nsError.domain == ASAuthorizationError.errorDomain,
                   nsError.code == ASAuthorizationError.canceled.rawValue {
                    return .none
                }
                state.errorMessage = error.localizedDescription
                state.showError = true
                return .none

            case .signInFailed(let message):
                state.errorMessage = message
                state.showError = true
                return .none

            case .binding:
                return .none
            }
        }
    }
}
