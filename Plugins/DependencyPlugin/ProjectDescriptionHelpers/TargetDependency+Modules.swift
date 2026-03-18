import Foundation
import ProjectDescription

// MARK: TargetDependency + App
public extension TargetDependency {
    static var app: Self {
        .project(target: ModulePath.App.name, path: .app)
    }
}

// MARK: TargetDependency + Feature
public extension TargetDependency {
    static var feature: Self {
        .project(target: ModulePath.Feature.name, path: .feature)
    }

    static func feature(sources module: ModulePath.Feature) -> Self {
        .project(target: ModulePath.Feature.name + module.rawValue, path: .feature(subModule: module))
    }
}

// MARK: TargetDependency + Domain
public extension TargetDependency {
    static var domain: Self {
        .project(target: ModulePath.Domain.name, path: .domain)
    }

    static func domain(sources module: ModulePath.Domain) -> Self {
        .project(target: ModulePath.Domain.name + module.rawValue, path: .domain(subModule: module))
    }
}

// MARK: TargetDependency + Shared
public extension TargetDependency {
    static var shared: Self {
        .project(target: ModulePath.Shared.name, path: .shared)
    }

    static func shared(sources module: ModulePath.Shared) -> Self {
        .project(target: ModulePath.Shared.name + module.rawValue, path: .shared(subModule: module))
    }
}
