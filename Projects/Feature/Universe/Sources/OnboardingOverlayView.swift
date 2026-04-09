import SwiftUI
import ComposableArchitecture
import DomainEntity
import SharedDesignSystem

struct OnboardingOverlayView: View {
    let store: StoreOf<UniverseFeature>

    init(store: StoreOf<UniverseFeature>) {
        self.store = store
    }

    @FocusState private var isNicknameFocused: Bool
    @State private var showTapHint = false
    @State private var showSubtitle = false
    @State private var showNicknameInput = false
    @State private var showPulsingRing = false

    var body: some View {
        if let step = store.onboardingStep, step != .completed {
            ZStack {
                switch step {
                case .welcome:
                    welcomeView
                case .nicknameInput:
                    nicknameInputView
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
            .task(id: step) {
                showTapHint = false
                showSubtitle = false
                showNicknameInput = false
                showPulsingRing = false
            }
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                TypewriterText(text: "◈⟡✦⋆ 님 소우주에 오신걸 환영합니다") {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        withAnimation(.easeInOut(duration: 0.5)) { showTapHint = true }
                    }
                }
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.4), radius: 12)
                Spacer()
                Text("탭하여 계속")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 60)
                    .opacity(showTapHint ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.send(.onboardingAdvanceFromWelcome, animation: .easeInOut) }
    }

    // MARK: - Nickname Input

    private var nicknameInputView: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { isNicknameFocused = false }

            VStack {
                VStack(spacing: 8) {
                    TypewriterText(text: "앞으로 불릴 이름을 알려주세요") {
                        withAnimation(.easeInOut(duration: 0.3)) { showSubtitle = true }
                    }
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.4), radius: 8)

                    if showSubtitle {
                        TypewriterText(text: "우주에서 사용할 닉네임이에요") {
                            withAnimation(.easeInOut(duration: 0.4)) { showNicknameInput = true }
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                isNicknameFocused = true
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .transition(.opacity)
                    }
                }
                .padding(.top, 100)

                Spacer()

                if showNicknameInput {
                    // 하단 입력창 (RecordPanelView 스타일)
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            TextField("", text: Binding(
                                get: { store.onboardingNickname },
                                set: { store.send(.onboardingNicknameChanged($0)) }
                            ))
                            .placeholder(when: store.onboardingNickname.isEmpty) {
                                Text("2~10자")
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .foregroundStyle(.white)
                            .font(.system(size: 16))
                            .focused($isNicknameFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit { store.send(.onboardingCheckNickname) }

                            Button {
                                store.send(.onboardingCheckNickname)
                            } label: {
                                Group {
                                    if store.onboardingNicknameChecking {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("중복확인")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(
                                        onboardingCanCheck
                                            ? AppColors.accent.opacity(0.6)
                                            : Color.white.opacity(0.08)
                                    )
                                )
                            }
                            .disabled(!onboardingCanCheck || store.onboardingNicknameChecking)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(onboardingBorderColor, lineWidth: 1)
                                )
                        )

                        HStack {
                            if let error = store.onboardingNicknameError {
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red.opacity(0.8))
                                    .transition(.opacity)
                            } else if store.onboardingNicknameAvailable == true {
                                Text("사용 가능한 닉네임이에요!")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.accent)
                                    .transition(.opacity)
                            }
                            Spacer()

                            if store.onboardingNicknameAvailable == true {
                                Button {
                                    store.send(.onboardingNicknameConfirm)
                                } label: {
                                    Group {
                                        if store.onboardingNicknameSaving {
                                            ProgressView().tint(.black)
                                        } else {
                                            Text("확인")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(AppColors.accent)
                                    )
                                }
                                .disabled(store.onboardingNicknameSaving)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: store.onboardingNicknameError)
                        .animation(.easeInOut(duration: 0.2), value: store.onboardingNicknameAvailable)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                    .background(
                        LinearGradient(
                            colors: [
                                .clear,
                                AppColors.surfaceDark.opacity(0.6),
                                AppColors.surfaceDark.opacity(0.92),
                                AppColors.surfaceDark,
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                        .padding(.top, -40)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var onboardingCanCheck: Bool {
        let trimmed = store.onboardingNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 10
    }

    private var onboardingBorderColor: Color {
        if store.onboardingNicknameError != nil {
            return .red.opacity(0.5)
        } else if store.onboardingNicknameAvailable == true {
            return AppColors.accent.opacity(0.5)
        }
        return Color.white.opacity(0.08)
    }

    // MARK: - Galaxy Birth Intro

    private var galaxyBirthIntroView: some View {
        VStack {
            VStack(spacing: 12) {
                let name = store.userDisplayName ?? "우주인"
                TypewriterText(text: "\(name)님의 은하가\n생겨나고 있어요")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.8), radius: 8)
                TypewriterText(text: "잠시만 기다려주세요...", delay: 0.8)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 100)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Monthly Galaxy Guide

    private var monthlyGalaxyGuideView: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack {
                TypewriterText(text: "매달 첫 접속 시\n새로운 은하가 만들어져요!") {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        withAnimation(.easeInOut(duration: 0.5)) { showTapHint = true }
                    }
                }
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .white.opacity(0.4), radius: 8)
                .padding(.top, 100)

                Spacer()

                Text("탭하여 계속")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 60)
                    .opacity(showTapHint ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.send(.onboardingAdvanceFromGuide, animation: .easeInOut) }
    }

    // MARK: - Tap Galaxy Prompt

    private var tapGalaxyPromptView: some View {
        GeometryReader { geo in
            let center = store.onboardingGalaxyScreenCenter
                ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                TypewriterText(text: "은하를 클릭해보세요!") {
                    withAnimation(.easeInOut(duration: 0.5)) { showPulsingRing = true }
                }
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.4), radius: 8)
                .position(x: geo.size.width / 2, y: min(center.y - 80, 140))

                if showPulsingRing {
                    PulsingRing()
                        .frame(width: 80, height: 80)
                        .position(center)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Create Star Prompt

    private var createStarPromptView: some View {
        ZStack {
            if !store.showRecordPanel {
                VStack {
                    VStack(spacing: 8) {
                        TypewriterText(text: "첫 번째 별을 만들어보세요!") {
                            withAnimation(.easeInOut(duration: 0.3)) { showSubtitle = true }
                        }
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.4), radius: 8)

                        if showSubtitle {
                            let name = store.userDisplayName ?? "우주인"
                            TypewriterText(
                                text: "별은 \(name)님이 적어주신 감정을 기반으로\n색이 결정돼요"
                            )
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                        }
                    }
                    .padding(.top, 100)
                    Spacer()
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Closing Message

    private var closingMessageView: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack {
                Spacer()
                let name = store.userDisplayName ?? "우주인"
                TypewriterText(text: "\(name)님의 별들로 소우주를 채워주세요!") {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        withAnimation(.easeInOut(duration: 0.5)) { showTapHint = true }
                    }
                }
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .white.opacity(0.6), radius: 12)
                Spacer()
                Text("탭하여 시작")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 60)
                    .opacity(showTapHint ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { store.send(.onboardingComplete, animation: .easeInOut) }
        .task {
            let name = store.userDisplayName ?? "우주인"
            let text = "\(name)님의 별들로 소우주를 채워주세요!"
            let typingDuration = Double(text.count) * 0.04 + 1.0
            try? await Task.sleep(nanoseconds: UInt64((typingDuration + 5.0) * 1_000_000_000))
            if Task.isCancelled { return }
            store.send(.onboardingComplete, animation: .easeInOut)
        }
    }
}

// MARK: - TypewriterText

private struct TypewriterText: View {
    let text: String
    var speed: TimeInterval = 0.04
    var delay: TimeInterval = 0
    var onCompleted: (() -> Void)? = nil

    @State private var displayedText = ""

    var body: some View {
        Text(displayedText)
            .task(id: text) {
                displayedText = ""
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                for char in text {
                    if Task.isCancelled { return }
                    displayedText.append(char)
                    try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                }
                onCompleted?()
            }
    }
}

// MARK: - Helpers

private extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct PulsingRing: View {
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
