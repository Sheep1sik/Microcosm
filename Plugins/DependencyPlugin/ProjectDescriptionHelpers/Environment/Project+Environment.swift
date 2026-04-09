import Foundation
import ProjectDescription

extension Project {
    public enum Environment {
        public static let deploymentTarget: DeploymentTargets = .iOS("17.0")
        public static let appName: String = "Microcosm"
        public static let displayName: String = "소우주"
        public static let bundlePrefix: String = "com.sheep1sik"

        public static let projectSettings: Settings = .settings(
            base: [
                "CODE_SIGN_STYLE": "Automatic",
                "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
                "OTHER_LDFLAGS": ["$(inherited)", "-ObjC"],
                "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                "GENERATE_DEBUG_SYMBOLS": "YES",
                "ENABLE_DEBUG_DYLIB": "NO",
            ],
            configurations: [
                .debug(name: .debug),
                .release(name: .release),
            ]
        )
    }
}
