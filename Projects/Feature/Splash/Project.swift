import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Splash.rawValue,
    targets: [
        .feature(
            sources: .Splash,
            target: .init(
                dependencies: [
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
