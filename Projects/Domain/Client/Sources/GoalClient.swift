import Foundation
import ComposableArchitecture
import DomainEntity

public struct GoalClient {
    public var observe: (String) -> AsyncStream<[Goal]>
    public var addGoal: (String, Goal) async throws -> Void
    public var updateGoal: (String, Goal) async throws -> Void
    public var deleteGoal: (String, String) async throws -> Void

    public init(
        observe: @escaping (String) -> AsyncStream<[Goal]>,
        addGoal: @escaping (String, Goal) async throws -> Void,
        updateGoal: @escaping (String, Goal) async throws -> Void,
        deleteGoal: @escaping (String, String) async throws -> Void
    ) {
        self.observe = observe
        self.addGoal = addGoal
        self.updateGoal = updateGoal
        self.deleteGoal = deleteGoal
    }
}

extension DependencyValues {
    public var goalClient: GoalClient {
        get { self[GoalClient.self] }
        set { self[GoalClient.self] = newValue }
    }
}
