import Foundation
import ComposableArchitecture
import DomainEntity
import FirebaseFirestore

public struct RecordClient {
    public var observe: (String) -> AsyncStream<[Record]>
    public var addRecord: (String, Record) async throws -> Void

    public init(
        observe: @escaping (String) -> AsyncStream<[Record]>,
        addRecord: @escaping (String, Record) async throws -> Void
    ) {
        self.observe = observe
        self.addRecord = addRecord
    }
}

extension RecordClient: DependencyKey {
    public static let liveValue = RecordClient(
        observe: { userId in
            AsyncStream { continuation in
                let db = Firestore.firestore()
                let listener = db.collection("users").document(userId).collection("records")
                    .order(by: "createdAt", descending: false)
                    .addSnapshotListener { snapshot, _ in
                        guard let documents = snapshot?.documents else { return }
                        let records = documents.compactMap { doc -> Record? in
                            var data = doc.data()
                            if let timestamp = data["createdAt"] as? Timestamp {
                                data["createdAt"] = timestamp.dateValue()
                            }
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
            let db = Firestore.firestore()
            var data = record.toFirestoreData()
            data["createdAt"] = Timestamp(date: record.createdAt)
            try await db.collection("users").document(userId).collection("records")
                .document(record.id).setData(data)
        }
    )
}

extension DependencyValues {
    public var recordClient: RecordClient {
        get { self[RecordClient.self] }
        set { self[RecordClient.self] = newValue }
    }
}
