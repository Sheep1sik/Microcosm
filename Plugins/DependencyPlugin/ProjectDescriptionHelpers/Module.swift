import Foundation

public enum ModulePath {
    case feature(Feature)
    case domain(Domain)
    case shared(Shared)
}

// MARK: AppModule
public extension ModulePath {
    enum App: String, CaseIterable {
        public static let name: String = "App"
        case iOS
    }
}

// MARK: FeatureModule
public extension ModulePath {
    enum Feature: String, CaseIterable {
        public static let name: String = "Feature"
        case Splash
        case Auth
        case Nickname
        case Main
        case Universe
        case Constellation
        case Profile
    }
}

// MARK: DomainModule
public extension ModulePath {
    enum Domain: String, CaseIterable {
        public static let name: String = "Domain"
        case Entity
        case Client
    }
}

// MARK: SharedModule
public extension ModulePath {
    enum Shared: String, CaseIterable {
        public static let name: String = "Shared"
        case DesignSystem
    }
}
