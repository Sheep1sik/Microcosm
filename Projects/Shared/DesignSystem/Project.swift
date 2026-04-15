import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Shared.name + ModulePath.Shared.DesignSystem.rawValue,
    targets: [
        .shared(
            sources: .DesignSystem,
            target: .init(
                dependencies: []
            )
        ),
    ]
)
