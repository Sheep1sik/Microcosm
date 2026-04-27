import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Core.name + ModulePath.Core.FirebaseKit.rawValue,
    targets: [
        .core(
            sources: .FirebaseKit,
            target: .init(
                dependencies: [
                    .domain(sources: .Entity),
                    .external(name: "FirebaseAuth"),
                    .external(name: "FirebaseFirestore"),
                ]
            )
        ),
        .core(
            tests: .FirebaseKit,
            target: .init(
                dependencies: [
                    .target(name: ModulePath.Core.name + ModulePath.Core.FirebaseKit.rawValue),
                ]
            )
        ),
    ]
)
