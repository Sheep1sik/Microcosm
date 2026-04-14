import Foundation
import DomainEntity

extension Goal {
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

extension SubGoal {
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
