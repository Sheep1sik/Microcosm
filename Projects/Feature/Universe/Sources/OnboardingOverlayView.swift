import SwiftUI
import ComposableArchitecture
import DomainEntity
import DomainClient

struct OnboardingOverlayView: View {
    let store: StoreOf<UniverseFeature>

    init(store: StoreOf<UniverseFeature>) {
        self.store = store
    }

    var body: some View {
        if let step = store.onboardingStep, step != .completed {
            ZStack {
                switch step {
                case .galaxyBirthIntro:
                    galaxyBirthIntroView
                case .monthlyGalaxyGuide:
                    monthlyGalaxyGuideView
                case .tapGalaxyPrompt:
                    tapGalaxyPromptView
                case .createStarPrompt:
                    createStarPromptView
                case .closingMessage:
                    closingMessageView
                case .completed:
                    EmptyView()
                }

            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.4), value: step)
        }
    }

    private var galaxyBirthIntroView: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Text("나만의 우주를 만들어요!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 8)
                Text("은하가 탄생하고 있어요...")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 120)
        }
        .allowsHitTesting(false)
    }

    private var monthlyGalaxyGuideView: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("매달 첫 접속 시\n은하가 만들어져요!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .white.opacity(0.4), radius: 8)
                Text("탭하여 계속")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.send(.onboardingAdvanceFromGuide, animation: .easeInOut) }
    }

    private var tapGalaxyPromptView: some View {
        GeometryReader { geo in
            let center = store.onboardingGalaxyScreenCenter
                ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Text("은하를 클릭해보세요!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.4), radius: 8)
                    .position(x: geo.size.width / 2, y: min(center.y - 80, 140))
                PulsingRing()
                    .frame(width: 80, height: 80)
                    .position(center)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var createStarPromptView: some View {
        ZStack {
            if !store.showRecordPanel {
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("첫 번째 별을 만들어보세요!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.4), radius: 8)
                        Text("한번 만든 별은 없앨 수 없어요")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var closingMessageView: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                let name = store.userDisplayName ?? "우주인"
                Text("\(name)님의 우주를\n지켜볼게요!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .white.opacity(0.6), radius: 12)
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.send(.onboardingComplete, animation: .easeInOut) }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                store.send(.onboardingComplete, animation: .easeInOut)
            }
        }
    }
}

private struct PulsingRing: View {
    @State private var isPulsing = false
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.3), lineWidth: 2)
                .scaleEffect(isPulsing ? 1.3 : 0.8)
                .opacity(isPulsing ? 0 : 0.8)
            Circle().stroke(.white.opacity(0.5), lineWidth: 1.5)
                .scaleEffect(isPulsing ? 1.0 : 0.6)
                .opacity(isPulsing ? 0.3 : 0.6)
        }
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
        .onAppear { isPulsing = true }
    }
}
