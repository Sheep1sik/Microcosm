#if DEBUG
import SwiftUI
import ComposableArchitecture
import SharedDesignSystem

// MARK: - Onboarding Step Previews

#Preview("0. Welcome") {
    OnboardingOverlayView(
        store: Store(
            initialState: OnboardingFeature.State(
                step: .welcome,
                userDisplayName: "테스트유저"
            )
        ) {
            OnboardingFeature()
        },
        showRecordPanel: false
    )
    .background(AppColors.background)
}

#Preview("0.5. Nickname Input") {
    OnboardingOverlayView(
        store: Store(
            initialState: OnboardingFeature.State(
                step: .nicknameInput,
                userDisplayName: "테스트유저"
            )
        ) {
            OnboardingFeature()
        },
        showRecordPanel: false
    )
    .background(AppColors.background)
}

#Preview("1. Galaxy Birth Intro") {
    OnboardingOverlayView(
        store: Store(
            initialState: OnboardingFeature.State(
                step: .galaxyBirthIntro,
                userDisplayName: "테스트유저"
            )
        ) {
            OnboardingFeature()
        },
        showRecordPanel: false
    )
    .background(AppColors.background)
}

#Preview("2. Monthly Galaxy Guide") {
    OnboardingOverlayView(
        store: Store(
            initialState: OnboardingFeature.State(
                step: .monthlyGalaxyGuide,
                userDisplayName: "테스트유저"
            )
        ) {
            OnboardingFeature()
        },
        showRecordPanel: false
    )
    .background(AppColors.background)
}

#Preview("3. Tap Galaxy Prompt") {
    OnboardingOverlayView(
        store: Store(
            initialState: OnboardingFeature.State(
                step: .tapGalaxyPrompt,
                galaxyScreenCenter: CGPoint(x: 200, y: 400),
                userDisplayName: "테스트유저"
            )
        ) {
            OnboardingFeature()
        },
        showRecordPanel: false
    )
    .background(AppColors.background)
}

#Preview("4. Create Star Prompt") {
    OnboardingOverlayView(
        store: Store(
            initialState: OnboardingFeature.State(
                step: .createStarPrompt,
                userDisplayName: "테스트유저"
            )
        ) {
            OnboardingFeature()
        },
        showRecordPanel: false
    )
    .background(AppColors.background)
}

#Preview("5. Closing Message") {
    OnboardingOverlayView(
        store: Store(
            initialState: OnboardingFeature.State(
                step: .closingMessage,
                userDisplayName: "테스트유저"
            )
        ) {
            OnboardingFeature()
        },
        showRecordPanel: false
    )
    .background(AppColors.background)
}

#endif
