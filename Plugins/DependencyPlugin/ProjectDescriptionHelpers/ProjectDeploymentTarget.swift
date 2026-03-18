import ProjectDescription

public enum ProjectDeploymentTarget: String {
    case debug = "Debug"
    case release = "Release"

    public var configurationName: ConfigurationName {
        ConfigurationName.configuration(self.rawValue)
    }
}
