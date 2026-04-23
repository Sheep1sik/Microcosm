import SwiftUI

struct ConstellationGuideStepView: View {
    let step: ConstellationFeature.State.GuideStep
    let userName: String
    let onTap: () -> Void

    @State private var showTapHint = false
    @State private var showSubtitle = false

    var body: some View {
        switch step {
        case .welcome, .closing:
            // 전체 화면 오버레이 — 탭하여 진행
            fullScreenGuide
        case .tapConstellation, .tapStar, .registerGoal:
            // 상단 텍스트만 — 유저가 직접 조작
            floatingHint
        }
    }

    // MARK: - Full Screen (welcome, closing)

    private var fullScreenGuide: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack {
                Spacer()

                GuideTypewriterText(text: guideTitle) {
                    withAnimation(.easeInOut(duration: 0.3)) { showSubtitle = true }
                }
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .white.opacity(0.4), radius: 12)

                if showSubtitle {
                    GuideTypewriterText(text: guideSubtitle, delay: 0.2) {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            withAnimation(.easeInOut(duration: 0.5)) { showTapHint = true }
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .transition(.opacity)
                }

                Spacer()

                Text(step == .closing ? "탭하여 시작" : "탭하여 계속")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 60)
                    .opacity(showTapHint ? 1 : 0)
            }
            .padding(.horizontal, 32)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .task(id: step) {
            showTapHint = false
            showSubtitle = false
        }
    }

    // MARK: - Floating Hint (tapConstellation, tapStar, registerGoal)

    private var floatingHint: some View {
        VStack {
            GuideTypewriterText(text: guideTitle) {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    withAnimation(.easeInOut(duration: 0.3)) { showSubtitle = true }
                }
            }
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.8), radius: 8)
            .padding(.top, 100)

            if showSubtitle {
                GuideTypewriterText(text: guideSubtitle, delay: 0.1)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 4)
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .allowsHitTesting(false)
        .task(id: step) {
            showTapHint = false
            showSubtitle = false
        }
    }

    // MARK: - Text Content

    private var guideTitle: String {
        switch step {
        case .welcome:
            return "\(userName)님,\n이곳은 별자리우주예요"
        case .tapConstellation:
            return "별자리를 탭해보세요!"
        case .tapStar:
            return "별을 탭해보세요!"
        case .registerGoal:
            return "목표를 등록해보세요!"
        case .closing:
            return "첫 번째 목표가 등록되었어요!"
        }
    }

    private var guideSubtitle: String {
        switch step {
        case .welcome:
            return "별자리에 목표를 등록하고 달성하면\n별이 빛나기 시작해요"
        case .tapConstellation:
            return "아무 별자리나 탭해서 들어가보세요"
        case .tapStar:
            return "별 하나를 선택하면\n목표를 등록할 수 있어요"
        case .registerGoal:
            return "첫 번째 목표를 적어보세요"
        case .closing:
            return "목표를 달성하면 별이 밝아지고\n모든 별이 빛나면 별자리가 완성돼요"
        }
    }
}

// MARK: - Guide Typewriter Text

private struct GuideTypewriterText: View {
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
