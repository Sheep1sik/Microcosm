import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Profile.rawValue,
    targets: [
        .feature(
            sources: .Profile,
            target: .init(
                dependencies: [
                    .feature(sources: .Nickname),
                    .domain(sources: .Client),
                    .domain(sources: .Entity),
                    .shared(sources: .DesignSystem),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
        .feature(
            tests: .Profile,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Feature.name + ModulePath.Feature.Profile.rawValue),
                    .feature(sources: .Nickname),
                    .domain(sources: .Client),
                    .domain(sources: .Entity),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
