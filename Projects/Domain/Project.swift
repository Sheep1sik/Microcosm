import ProjectDescription
import DependencyPlugin

let targets: [Target] = [
    .domain(
        target: .init(
            dependencies: [
                .domain(sources: .Entity),
                .domain(sources: .Client),
            ]
        )
    ),
]

let project: Project = .makeModule(name: "Domain", targets: targets)
