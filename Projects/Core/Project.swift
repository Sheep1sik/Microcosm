import ProjectDescription
import DependencyPlugin

let targets: [Target] = [
    .core(
        target: .init(
            dependencies: [
                .core(sources: .FirebaseKit),
            ]
        )
    ),
]

let project: Project = .makeModule(name: "Core", targets: targets)
