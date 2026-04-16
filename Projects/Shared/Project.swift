import ProjectDescription
import DependencyPlugin

let targets: [Target] = [
    .shared(
        target: .init(
            dependencies: [
                .shared(sources: .DesignSystem),
                .shared(sources: .Util),
            ]
        )
    ),
]

let project: Project = .makeModule(name: "Shared", targets: targets)
