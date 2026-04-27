import Foundation
import ProjectDescription

extension ProjectDescription.Path {
    static var app: Self {
        .relativeToRoot("Projects/\(ModulePath.App.name)")
    }
}

extension ProjectDescription.Path {
    static var feature: Self {
        .relativeToRoot("Projects/\(ModulePath.Feature.name)")
    }

    static func feature(subModule: ModulePath.Feature) -> Self {
        .relativeToRoot("Projects/\(ModulePath.Feature.name)/\(subModule.rawValue)")
    }
}

extension ProjectDescription.Path {
    static var domain: Self {
        .relativeToRoot("Projects/\(ModulePath.Domain.name)")
    }

    static func domain(subModule: ModulePath.Domain) -> Self {
        .relativeToRoot("Projects/\(ModulePath.Domain.name)/\(subModule.rawValue)")
    }
}

extension ProjectDescription.Path {
    static var core: Self {
        .relativeToRoot("Projects/\(ModulePath.Core.name)")
    }

    static func core(subModule: ModulePath.Core) -> Self {
        .relativeToRoot("Projects/\(ModulePath.Core.name)/\(subModule.rawValue)")
    }
}

extension ProjectDescription.Path {
    static var shared: Self {
        .relativeToRoot("Projects/\(ModulePath.Shared.name)")
    }

    static func shared(subModule: ModulePath.Shared) -> Self {
        .relativeToRoot("Projects/\(ModulePath.Shared.name)/\(subModule.rawValue)")
    }
}
