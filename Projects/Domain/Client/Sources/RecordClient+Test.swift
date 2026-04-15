import Foundation
import ComposableArchitecture
import DomainEntity

extension RecordClient: TestDependencyKey {
    public static let testValue = RecordClient(
        observe: unimplemented("\(Self.self).observe"),
        addRecord: unimplemented("\(Self.self).addRecord")
    )
}
