import XCTest
import ComposableArchitecture
@testable import FeatureRoot

@MainActor
final class RootFeatureTests: XCTestCase {
    func test_initialState_splash모드() {
        let state = RootFeature.State()
        XCTAssertEqual(state.mode, .splash)
        XCTAssertNil(state.userId)
        XCTAssertNil(state.displayName)
    }

    func test_State_Mode값() {
        XCTAssertEqual(RootFeature.State.Mode.splash, .splash)
        XCTAssertNotEqual(RootFeature.State.Mode.splash, .login)
        XCTAssertNotEqual(RootFeature.State.Mode.login, .main)
    }
}
