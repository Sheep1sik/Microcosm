import Foundation
import ComposableArchitecture
import CoreFirebaseKit
import DomainEntity

extension RecordClient: DependencyKey {
    public static let liveValue = RecordClient(
        observe: { userId in
            AsyncStream { continuation in
                let listener = FirestoreDB.shared
                    .collection("users").document(userId).collection("records")
                    .order(by: "createdAt", descending: false)
                    .addSnapshotListener { snapshot, _ in
                        guard let documents = snapshot?.documents else { return }
                        let records = documents.compactMap { doc -> Record? in
                            var data = doc.data()
                            FirestoreDictConverter.timestampsToDates(&data, keys: ["createdAt"])
                            return Record.fromFirestoreData(data, id: doc.documentID)
                        }
                        continuation.yield(records)
                    }
                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        },
        addRecord: { userId, record in
            var data = record.toFirestoreData()
            data["createdAt"] = Timestamp(date: record.createdAt)
            try await FirestoreDB.shared
                .collection("users").document(userId).collection("records")
                .document(record.id).setData(data)
        }
    )
}
