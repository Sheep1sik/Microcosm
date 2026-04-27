// swift-tools-version: 6.0
@preconcurrency import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [
            "FirebaseAuth": .staticFramework,
            "FirebaseFirestore": .staticFramework,
            "GoogleSignIn": .staticFramework,
            "GoogleSignInSwift": .staticFramework,
            "ComposableArchitecture": .framework,
        ]
    )
#endif

let package = Package(
    name: "Microcosm",
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    ]
)
