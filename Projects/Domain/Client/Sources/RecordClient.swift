import Foundation
import ComposableArchitecture
import DomainEntity

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

extension DependencyValues {
    public var recordClient: RecordClient {
        get { self[RecordClient.self] }
        set { self[RecordClient.self] = newValue }
    }
}
