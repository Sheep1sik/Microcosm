import SwiftUI
import ComposableArchitecture

public struct SplashView: View {
    let store: StoreOf<SplashFeature>

    public init(store: StoreOf<SplashFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.024, blue: 0.031)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.6))

                Text("소우주")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))

                ProgressView()
                    .tint(.white.opacity(0.5))
                    .padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { store.send(.onAppear) }
    }
}
