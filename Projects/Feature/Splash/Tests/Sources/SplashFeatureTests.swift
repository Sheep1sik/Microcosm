import XCTest
import ComposableArchitecture
@testable import FeatureSplash

@MainActor
final class SplashFeatureTests: XCTestCase {

    func test_initialState_기본생성() {
        let state = SplashFeature.State()
        XCTAssertEqual(state, SplashFeature.State())
    }

    func test_onAppear_상태변경없음() async {
        let store = TestStore(initialState: SplashFeature.State()) {
            SplashFeature()
        }

        await store.send(.onAppear)
    }
}
