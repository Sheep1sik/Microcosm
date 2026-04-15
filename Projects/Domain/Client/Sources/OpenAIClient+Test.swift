import Foundation
import ComposableArchitecture
import DomainEntity

extension OpenAIClient: TestDependencyKey {
    public static let testValue = OpenAIClient(
        analyzeColor: unimplemented("\(Self.self).analyzeColor"),
        analyzeEmotion: unimplemented("\(Self.self).analyzeEmotion")
    )
}
