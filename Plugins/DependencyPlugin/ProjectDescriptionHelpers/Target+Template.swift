import Foundation
import ProjectDescription

public extension Target {
    init(
        name: String = "",
        destinations: Destinations = [.iPhone],
        product: Product = .staticLibrary,
        bundleId: String = "",
        deploymentTargets: DeploymentTargets? = Project.Environment.deploymentTarget,
        infoPlist: InfoPlist? = .default,
        sources: SourceFilesList? = .sources,
        resources: ResourceFileElements? = nil,
        entitlements: Entitlements? = nil,
        scripts: [TargetScript] = [],
        dependencies: [TargetDependency] = [],
        settings: Settings? = nil
    ) {
        self = .target(
            name: name,
            destinations: destinations,
            product: product,
            bundleId: bundleId,
            deploymentTargets: deploymentTargets,
            infoPlist: infoPlist,
            sources: sources,
            resources: resources,
            entitlements: entitlements,
            scripts: scripts,
            dependencies: dependencies,
            settings: settings
        )
    }
}
