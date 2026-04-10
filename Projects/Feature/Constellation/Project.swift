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
                    .domain(sources: .Client),
                    .shared(sources: .DesignSystem),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
        .feature(
            tests: .Constellation,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Feature.name + ModulePath.Feature.Constellation.rawValue),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
