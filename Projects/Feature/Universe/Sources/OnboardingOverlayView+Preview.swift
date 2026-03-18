#if DEBUG
import SwiftUI
import ComposableArchitecture
import DomainEntity

// MARK: - Onboarding Step Previews

#Preview("0. Welcome") {
    OnboardingOverlayView(
        store: Store(
            initialState: UniverseFeature.State(
                onboardingStep: .welcome,
                userDisplayName: "테스트유저"
            )
        ) {
            UniverseFeature()
        }
    )
    .background(Color(red: 0.012, green: 0.024, blue: 0.031))
}

#Preview("0.5. Nickname Input") {
    OnboardingOverlayView(
        store: Store(
            initialState: UniverseFeature.State(
                onboardingStep: .nicknameInput,
                userDisplayName: "테스트유저"
            )
        ) {
            UniverseFeature()
        }
    )
    .background(Color(red: 0.012, green: 0.024, blue: 0.031))
}

#Preview("1. Galaxy Birth Intro") {
    OnboardingOverlayView(
        store: Store(
            initialState: UniverseFeature.State(
                onboardingStep: .galaxyBirthIntro,
                userDisplayName: "테스트유저"
            )
        ) {
            UniverseFeature()
        }
    )
    .background(Color(red: 0.012, green: 0.024, blue: 0.031))
}

#Preview("2. Monthly Galaxy Guide") {
    OnboardingOverlayView(
        store: Store(
            initialState: UniverseFeature.State(
                onboardingStep: .monthlyGalaxyGuide,
                userDisplayName: "테스트유저"
            )
        ) {
            UniverseFeature()
        }
    )
    .background(Color(red: 0.012, green: 0.024, blue: 0.031))
}

#Preview("3. Tap Galaxy Prompt") {
    OnboardingOverlayView(
        store: Store(
            initialState: UniverseFeature.State(
                onboardingStep: .tapGalaxyPrompt,
                onboardingGalaxyScreenCenter: CGPoint(x: 200, y: 400),
                userDisplayName: "테스트유저"
            )
        ) {
            UniverseFeature()
        }
    )
    .background(Color(red: 0.012, green: 0.024, blue: 0.031))
}

#Preview("4. Create Star Prompt") {
    OnboardingOverlayView(
        store: Store(
            initialState: UniverseFeature.State(
                onboardingStep: .createStarPrompt,
                userDisplayName: "테스트유저",
                isInGalaxyDetail: true
            )
        ) {
            UniverseFeature()
        }
    )
    .background(Color(red: 0.012, green: 0.024, blue: 0.031))
}

#Preview("5. Closing Message") {
    OnboardingOverlayView(
        store: Store(
            initialState: UniverseFeature.State(
                onboardingStep: .closingMessage,
                userDisplayName: "테스트유저"
            )
        ) {
            UniverseFeature()
        }
    )
    .background(Color(red: 0.012, green: 0.024, blue: 0.031))
}

#endif
