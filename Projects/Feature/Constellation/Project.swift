import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Constellation.rawValue,
    targets: [
        .feature(
            sources: .Constellation,
            target: .init(
                dependencies: [
                    .domain(sources: .Entity),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
