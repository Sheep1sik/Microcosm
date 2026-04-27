import Foundation
import ComposableArchitecture
import CoreFirebaseKit
import DomainEntity

extension GoalClient: DependencyKey {
    public static let liveValue = GoalClient(
        observe: { userId in
            AsyncStream { continuation in
                let listener = FirestoreDB.shared
                    .collection("users").document(userId).collection("goals")
                    .order(by: "createdAt", descending: false)
                    .addSnapshotListener { snapshot, _ in
                        guard let documents = snapshot?.documents else { return }
                        let goals = documents.compactMap { doc -> Goal? in
                            var data = doc.data()
                            FirestoreDictConverter.timestampsToDates(
                                &data,
                                keys: ["createdAt", "completedAt"]
                            )
                            if var subGoals = data["subGoals"] as? [[String: Any]] {
                                for i in subGoals.indices {
                                    FirestoreDictConverter.timestampsToDates(
                                        &subGoals[i],
                                        keys: ["completedAt"]
                                    )
                                }
                                data["subGoals"] = subGoals
                            }
                            return Goal.fromFirestoreData(data, id: doc.documentID)
                        }
                        continuation.yield(goals)
                    }
                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        },
        addGoal: { userId, goal in
            try await FirestoreDB.shared
                .collection("users").document(userId).collection("goals")
                .document(goal.id).setData(encodeGoal(goal))
        },
        updateGoal: { userId, goal in
            try await FirestoreDB.shared
                .collection("users").document(userId).collection("goals")
                .document(goal.id).setData(encodeGoal(goal), merge: true)
        },
        deleteGoal: { userId, goalId in
            try await FirestoreDB.shared
                .collection("users").document(userId).collection("goals")
                .document(goalId).delete()
        }
    )
}

private func encodeGoal(_ goal: Goal) -> [String: Any] {
    var data = goal.toFirestoreData()
    data["createdAt"] = Timestamp(date: goal.createdAt)
    if let completedAt = goal.completedAt {
        data["completedAt"] = Timestamp(date: completedAt)
    }
    if var subGoals = data["subGoals"] as? [[String: Any]] {
        for i in subGoals.indices {
            FirestoreDictConverter.datesToTimestamps(&subGoals[i], keys: ["completedAt"])
        }
        data["subGoals"] = subGoals
    }
    return data
}
