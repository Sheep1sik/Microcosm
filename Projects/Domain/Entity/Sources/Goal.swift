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

    // MARK: - Firestore Serialization

    public func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "constellationId": constellationId,
            "starIndex": starIndex,
            "title": title,
            "createdAt": createdAt,
            "subGoals": subGoals.map { $0.toFirestoreData() },
        ]
        if let completedAt {
            data["completedAt"] = completedAt
        }
        return data
    }

    public static func fromFirestoreData(_ data: [String: Any], id: String) -> Goal? {
        guard let constellationId = data["constellationId"] as? String,
              let starIndex = data["starIndex"] as? Int,
              let title = data["title"] as? String else {
            return nil
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Date {
            createdAt = timestamp
        } else {
            createdAt = .now
        }

        let completedAt = data["completedAt"] as? Date

        let subGoalsData = data["subGoals"] as? [[String: Any]] ?? []
        let subGoals = subGoalsData.compactMap { SubGoal.fromFirestoreData($0) }

        return Goal(
            id: id,
            constellationId: constellationId,
            starIndex: starIndex,
            title: title,
            subGoals: subGoals,
            createdAt: createdAt,
            completedAt: completedAt
        )
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

    // MARK: - Firestore Serialization

    public func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "title": title,
            "isCompleted": isCompleted,
        ]
        if let completedAt {
            data["completedAt"] = completedAt
        }
        return data
    }

    public static func fromFirestoreData(_ data: [String: Any]) -> SubGoal? {
        guard let id = data["id"] as? String,
              let title = data["title"] as? String else {
            return nil
        }
        let isCompleted = data["isCompleted"] as? Bool ?? false
        let completedAt = data["completedAt"] as? Date
        return SubGoal(id: id, title: title, isCompleted: isCompleted, completedAt: completedAt)
    }
}
