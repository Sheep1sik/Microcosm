import ProjectDescription
import DependencyPlugin

let targets: [Target] = [
    .shared(
        target: .init(
            dependencies: [
                .shared(sources: .DesignSystem),
            ]
        )
    ),
]

let project: Project = .makeModule(name: "Shared", targets: targets)
