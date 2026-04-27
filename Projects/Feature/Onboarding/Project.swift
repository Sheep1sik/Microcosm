import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Onboarding.rawValue,
    targets: [
        .feature(
            sources: .Onboarding,
            target: .init(
                dependencies: [
                    .feature(sources: .Nickname),
                    .domain(sources: .Client),
                    .shared(sources: .DesignSystem),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
        .feature(
            tests: .Onboarding,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Feature.name + ModulePath.Feature.Onboarding.rawValue),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
