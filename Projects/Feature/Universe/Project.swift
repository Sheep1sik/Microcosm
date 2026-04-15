import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Universe.rawValue,
    targets: [
        .feature(
            sources: .Universe,
            target: .init(
                dependencies: [
                    .feature(sources: .Nickname),
                    .domain(sources: .Entity),
                    .domain(sources: .Client),
                    .shared(sources: .DesignSystem),
                    .shared(sources: .RecordVisuals),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
        .feature(
            tests: .Universe,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Feature.name + ModulePath.Feature.Universe.rawValue),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
