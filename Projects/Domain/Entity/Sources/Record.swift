import Foundation

public struct Record: Identifiable, Equatable, Hashable {
    public let id: String
    public var content: String
    public var createdAt: Date
    public var color: RecordColor
    public var visualProfile: StarVisualProfile?
    public var starName: String
    public var isOnboardingRecord: Bool
    public var starPosition: StarPosition?

    public var resolvedProfile: StarVisualProfile {
        visualProfile ?? StarVisualProfile.from(legacyColor: color)
    }

    public init(
        id: String = UUID().uuidString,
        content: String,
        color: RecordColor = .fallback,
        visualProfile: StarVisualProfile? = nil,
        starName: String = "",
        createdAt: Date = .now,
        isOnboardingRecord: Bool = false,
        starPosition: StarPosition? = nil
    ) {
        self.id = id
        self.content = content
        self.color = color
        self.visualProfile = visualProfile
        self.starName = starName
        self.createdAt = createdAt
        self.isOnboardingRecord = isOnboardingRecord
        self.starPosition = starPosition
    }
}
