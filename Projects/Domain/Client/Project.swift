import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Domain.name + ModulePath.Domain.Client.rawValue,
    targets: [
        .domain(
            sources: .Client,
            target: .init(
                dependencies: [
                    .domain(sources: .Entity),
                    .core(sources: .FirebaseKit),
                    .external(name: "FirebaseAuth"),
                    .external(name: "FirebaseFirestore"),
                    .external(name: "GoogleSignIn"),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
        .domain(
            tests: .Client,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Domain.name + ModulePath.Domain.Client.rawValue),
                    .external(name: "ComposableArchitecture"),
                ]
            )
        ),
    ]
)
