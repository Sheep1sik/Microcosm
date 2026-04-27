import SwiftUI
import ComposableArchitecture
import AuthenticationServices
import DomainClient
import SharedDesignSystem

public struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>

    public init(store: StoreOf<LoginFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.3, green: 0.4, blue: 0.8).opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(y: -100)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, AppColors.accent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("소우주")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white)

                    Text("기억을 우주에 새기다")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        store.send(.appleSignInRequested(request))
                    } onCompletion: { result in
                        store.send(.appleSignInCompleted(result))
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)

                    Button {
                        store.send(.googleSignInTapped)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Google로 로그인")
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.dark)
        .alert("로그인 실패", isPresented: $store.showError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "알 수 없는 오류가 발생했습니다")
        }
    }
}
