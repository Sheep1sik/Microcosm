import Foundation
import ProjectDescription

public extension Project {
    static func makeModule(
        name: String,
        options: Project.Options = .options(),
        packages: [Package] = [],
        settings: Settings? = Project.Environment.projectSettings,
        targets: [Target],
        schemes: [Scheme] = [],
        additionalFiles: [FileElement] = [],
        resourceSynthesizers: [ResourceSynthesizer] = []
    ) -> Self {
        .init(
            name: name,
            options: options,
            packages: packages,
            settings: settings,
            targets: targets,
            schemes: schemes,
            additionalFiles: additionalFiles,
            resourceSynthesizers: resourceSynthesizers
        )
    }
}
