import Foundation
import ProjectDescription

public extension Target {
    static func app(
        module: ModulePath.App,
        target: Target
    ) -> Target {
        var newTarget = target
        newTarget.name = Project.Environment.appName
        switch module {
        case .iOS:
            newTarget.product = .app
            newTarget.bundleId = "\(Project.Environment.bundlePrefix).\(Project.Environment.appName)"
            newTarget.resources = ["Resources/**"]
            newTarget.sources = .sources
        }
        return newTarget
    }
}
