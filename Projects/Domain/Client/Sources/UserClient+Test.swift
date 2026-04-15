import Foundation
import ComposableArchitecture
import DomainEntity

extension UserClient: TestDependencyKey {
    public static let testValue = UserClient(
        observe: unimplemented("\(Self.self).observe"),
        createIfNeeded: unimplemented("\(Self.self).createIfNeeded"),
        setNickname: unimplemented("\(Self.self).setNickname"),
        checkNickname: unimplemented("\(Self.self).checkNickname"),
        updateDisplayName: unimplemented("\(Self.self).updateDisplayName"),
        updateEmail: unimplemented("\(Self.self).updateEmail"),
        markOnboardingCompleted: unimplemented("\(Self.self).markOnboardingCompleted"),
        resetOnboarding: unimplemented("\(Self.self).resetOnboarding"),
        markConstellationGuideSeen: unimplemented("\(Self.self).markConstellationGuideSeen")
    )
}
