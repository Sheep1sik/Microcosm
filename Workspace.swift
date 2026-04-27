import ProjectDescription

let workspace = Workspace(
    name: "Microcosm",
    projects: [
        "Projects/*",
    ],
    generationOptions: .options(
        enableAutomaticXcodeSchemes: true
    )
)
