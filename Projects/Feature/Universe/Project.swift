import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Universe.rawValue,
    targets: [
        .feature(
            sources: .Universe,
            target: .init(
                dependencies: [
                    .domain(sources: .Entity),
                    .domain(sources: .Client),
                    .shared(sources: .DesignSystem),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
