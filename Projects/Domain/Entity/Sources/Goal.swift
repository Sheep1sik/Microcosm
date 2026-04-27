import Foundation

// MARK: - Goal (목표)

public struct Goal: Identifiable, Equatable, Hashable {
    public let id: String
    public var constellationId: String   // "ORI"
    public var starIndex: Int
    public var title: String
    public var subGoals: [SubGoal]
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        id: String = UUID().uuidString,
        constellationId: String,
        starIndex: Int,
        title: String,
        subGoals: [SubGoal] = [],
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.constellationId = constellationId
        self.starIndex = starIndex
        self.title = title
        self.subGoals = subGoals
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    // MARK: - Computed

    public var isCompleted: Bool {
        if subGoals.isEmpty {
            return completedAt != nil
        }
        return subGoals.allSatisfy(\.isCompleted)
    }

    public var completionRatio: Double {
        if subGoals.isEmpty {
            return completedAt != nil ? 1.0 : 0.0
        }
        let completed = subGoals.filter(\.isCompleted).count
        return Double(completed) / Double(subGoals.count)
    }
}

// MARK: - SubGoal (하위 목표)

public struct SubGoal: Identifiable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var isCompleted: Bool
    public var completedAt: Date?

    public init(
        id: String = UUID().uuidString,
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
