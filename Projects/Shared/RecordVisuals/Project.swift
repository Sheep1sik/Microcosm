import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Shared.name + ModulePath.Shared.RecordVisuals.rawValue,
    targets: [
        .shared(
            sources: .RecordVisuals,
            target: .init(
                dependencies: [
                    .domain(sources: .Entity),
                ]
            )
        ),
    ]
)
