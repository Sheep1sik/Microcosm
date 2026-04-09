import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Auth.rawValue,
    targets: [
        .feature(
            sources: .Auth,
            target: .init(
                dependencies: [
                    .domain(sources: .Client),
                    .shared(sources: .DesignSystem),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
