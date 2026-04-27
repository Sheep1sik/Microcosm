import Foundation
import ProjectDescription

public extension Target {
    static func shared(target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Shared.name
        newTarget.sources = .sources
        return newTarget
    }

    static func shared(sources module: ModulePath.Shared, target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Shared.name + module.rawValue
        newTarget.sources = .sources
        return newTarget
    }

    static func shared(tests module: ModulePath.Shared, target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Shared.name + module.rawValue + "Tests"
        newTarget.product = .unitTests
        newTarget.sources = .tests
        return newTarget
    }
}
