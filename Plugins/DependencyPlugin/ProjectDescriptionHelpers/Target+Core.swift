import Foundation
import ProjectDescription

public extension Target {
    static func core(target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Core.name
        newTarget.sources = .sources
        return newTarget
    }

    static func core(sources module: ModulePath.Core, target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Core.name + module.rawValue
        newTarget.sources = .sources
        return newTarget
    }

    static func core(tests module: ModulePath.Core, target: Target) -> Self {
        var newTarget = target
        newTarget.name = ModulePath.Core.name + module.rawValue + "Tests"
        newTarget.product = .unitTests
        newTarget.sources = .tests
        return newTarget
    }
}
