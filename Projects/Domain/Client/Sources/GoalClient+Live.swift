import Foundation
import ComposableArchitecture
import DomainEntity
import FirebaseFirestore

extension GoalClient: DependencyKey {
    public static let liveValue = GoalClient(
        observe: { userId in
            AsyncStream { continuation in
                let db = Firestore.firestore()
                let listener = db.collection("users").document(userId).collection("goals")
                    .order(by: "createdAt", descending: false)
                    .addSnapshotListener { snapshot, _ in
                        guard let documents = snapshot?.documents else { return }
                        let goals = documents.compactMap { doc -> Goal? in
                            var data = doc.data()
                            if let timestamp = data["createdAt"] as? Timestamp {
                                data["createdAt"] = timestamp.dateValue()
                            }
                            if let timestamp = data["completedAt"] as? Timestamp {
                                data["completedAt"] = timestamp.dateValue()
                            }
                            // SubGoal 내 Timestamp 변환
                            if var subGoals = data["subGoals"] as? [[String: Any]] {
                                for i in subGoals.indices {
                                    if let ts = subGoals[i]["completedAt"] as? Timestamp {
                                        subGoals[i]["completedAt"] = ts.dateValue()
                                    }
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
            let db = Firestore.firestore()
            var data = goal.toFirestoreData()
            data["createdAt"] = Timestamp(date: goal.createdAt)
            if let completedAt = goal.completedAt {
                data["completedAt"] = Timestamp(date: completedAt)
            }
            // SubGoal 내 Date → Timestamp 변환
            if var subGoals = data["subGoals"] as? [[String: Any]] {
                for i in subGoals.indices {
                    if let date = subGoals[i]["completedAt"] as? Date {
                        subGoals[i]["completedAt"] = Timestamp(date: date)
                    }
                }
                data["subGoals"] = subGoals
            }
            try await db.collection("users").document(userId).collection("goals")
                .document(goal.id).setData(data)
        },
        updateGoal: { userId, goal in
            let db = Firestore.firestore()
            var data = goal.toFirestoreData()
            data["createdAt"] = Timestamp(date: goal.createdAt)
            if let completedAt = goal.completedAt {
                data["completedAt"] = Timestamp(date: completedAt)
            }
            if var subGoals = data["subGoals"] as? [[String: Any]] {
                for i in subGoals.indices {
                    if let date = subGoals[i]["completedAt"] as? Date {
                        subGoals[i]["completedAt"] = Timestamp(date: date)
                    }
                }
                data["subGoals"] = subGoals
            }
            try await db.collection("users").document(userId).collection("goals")
                .document(goal.id).setData(data, merge: true)
        },
        deleteGoal: { userId, goalId in
            let db = Firestore.firestore()
            try await db.collection("users").document(userId).collection("goals")
                .document(goalId).delete()
        }
    )
}
