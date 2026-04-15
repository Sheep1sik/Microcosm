import Foundation
import ComposableArchitecture
import DomainEntity

extension GoalClient: TestDependencyKey {
    public static let testValue = GoalClient(
        observe: unimplemented("\(Self.self).observe"),
        addGoal: unimplemented("\(Self.self).addGoal"),
        updateGoal: unimplemented("\(Self.self).updateGoal"),
        deleteGoal: unimplemented("\(Self.self).deleteGoal")
    )
}
