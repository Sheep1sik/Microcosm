import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Nickname.rawValue,
    targets: [
        .feature(
            sources: .Nickname,
            target: .init(
                dependencies: [
                    .domain(sources: .Client),
                    .domain(sources: .Entity),
                    .shared(sources: .DesignSystem),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
        .feature(
            tests: .Nickname,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Feature.name + ModulePath.Feature.Nickname.rawValue),
                    .domain(sources: .Client),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
