import Foundation
import ProjectDescription

public extension Target {
    static func domain(target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Domain.name
        newTarget.sources = .sources
        return newTarget
    }

    static func domain(sources module: ModulePath.Domain, target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Domain.name + module.rawValue
        newTarget.sources = .sources
        return newTarget
    }

    static func domain(tests module: ModulePath.Domain, target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Domain.name + module.rawValue + "Tests"
        newTarget.product = .unitTests
        newTarget.sources = .tests
        return newTarget
    }
}
