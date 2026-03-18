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
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
