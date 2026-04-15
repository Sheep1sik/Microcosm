import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Splash.rawValue,
    targets: [
        .feature(
            sources: .Splash,
            target: .init(
                dependencies: [
                    .shared(sources: .DesignSystem),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
        .feature(
            tests: .Splash,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Feature.name + ModulePath.Feature.Splash.rawValue),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
