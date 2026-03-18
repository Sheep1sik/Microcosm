import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: .all,
        plugins: [
            .local(path: .relativeToRoot("./Plugins/DependencyPlugin")),
        ]
    )
)
