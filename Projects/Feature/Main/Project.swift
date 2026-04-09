import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Main.rawValue,
    targets: [
        .feature(
            sources: .Main,
            target: .init(
                dependencies: [
                    .feature(sources: .Universe),
                    .feature(sources: .Constellation),
                    .feature(sources: .Profile),
                    .domain(sources: .Client),
                    .domain(sources: .Entity),
                    .shared(sources: .DesignSystem),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
