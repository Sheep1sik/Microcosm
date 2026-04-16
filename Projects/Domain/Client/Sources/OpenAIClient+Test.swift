import Foundation
import ComposableArchitecture

extension OpenAIClient: TestDependencyKey {
    public static let testValue = OpenAIClient(
        analyzeColor: unimplemented("\(Self.self).analyzeColor"),
        analyzeEmotion: unimplemented("\(Self.self).analyzeEmotion")
    )
}
