import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Feature.name + ModulePath.Feature.Root.rawValue,
    targets: [
        .feature(
            sources: .Root,
            target: .init(
                dependencies: [
                    .feature(sources: .Splash),
                    .feature(sources: .Auth),
                    .feature(sources: .Main),
                    .domain(sources: .Entity),
                    .domain(sources: .Client),
                    .external(name: "ComposableArchitecture"),
                    .external(name: "FirebaseAuth"),
                ]
            )
        ),
        .feature(
            tests: .Root,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Feature.name + ModulePath.Feature.Root.rawValue),
                    .domain(sources: .Client),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
