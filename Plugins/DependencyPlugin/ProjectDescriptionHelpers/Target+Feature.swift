import Foundation
import ProjectDescription

public extension Target {
    static func feature(target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Feature.name
        newTarget.sources = .sources
        return newTarget
    }

    static func feature(sources module: ModulePath.Feature, target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Feature.name + module.rawValue
        newTarget.sources = .sources
        return newTarget
    }

    static func feature(tests module: ModulePath.Feature, target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Feature.name + module.rawValue + "Tests"
        newTarget.product = .unitTests
        newTarget.sources = .tests
        return newTarget
    }
}
