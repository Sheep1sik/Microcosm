import ProjectDescription
import DependencyPlugin

let targets: [Target] = [
    .feature(
        target: .init(
            dependencies: [
                .feature(sources: .Splash),
                .feature(sources: .Auth),
                .feature(sources: .Nickname),
                .feature(sources: .Main),
                .feature(sources: .Universe),
                .feature(sources: .Profile),
            ]
        )
    ),
]

let project: Project = .makeModule(name: "Feature", targets: targets)
