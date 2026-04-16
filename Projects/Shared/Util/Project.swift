import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.Shared.name + ModulePath.Shared.Util.rawValue,
    targets: [
        .shared(
            sources: .Util,
            target: .init(
                dependencies: []
            )
        ),
    ]
)
