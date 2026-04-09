import ProjectDescription
import DependencyPlugin

let project = Project.makeModule(
    name: ModulePath.App.name,
    settings: .settings(
        base: [
            "CODE_SIGN_STYLE": "Automatic",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            "OTHER_LDFLAGS": ["$(inherited)", "-ObjC"],
            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            "GENERATE_DEBUG_SYMBOLS": "YES",
            "ENABLE_DEBUG_DYLIB": "NO",
        ],
        configurations: [
            .debug(name: .debug, xcconfig: "Secrets.xcconfig"),
            .release(name: .release, xcconfig: "Secrets.xcconfig"),
        ]
    ),
    targets: [
        .app(
            module: .iOS,
            target: .init(
                infoPlist: .extendingDefault(with: [
                    "CFBundleDisplayName": "소우주",
                    "UILaunchScreen": ["UIColorName": "LaunchBackground"],
                    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                    "UIUserInterfaceStyle": "Dark",
                    "CFBundleURLTypes": [
                        [
                            "CFBundleTypeRole": "Editor",
                            "CFBundleURLSchemes": ["com.googleusercontent.apps.401642093565-inr52e52ielptgsjfk0lcm62uuecio4j"],
                        ],
                    ],
                    "GIDClientID": "401642093565-inr52e52ielptgsjfk0lcm62uuecio4j.apps.googleusercontent.com",
                    "OPENAI_API_KEY": "$(OPENAI_API_KEY)",
                ]),
                entitlements: "Resources/Microcosm.entitlements",
                dependencies: [
                    .feature,
                    .domain,
                    .shared,
                ]
            )
        ),
    ]
)
