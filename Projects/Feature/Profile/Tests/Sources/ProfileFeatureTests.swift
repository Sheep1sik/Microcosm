import XCTest
import ComposableArchitecture
@testable import FeatureProfile
import FeatureNickname
import DomainClient
import DomainEntity

@MainActor
final class ProfileFeatureTests: XCTestCase {

    // MARK: - Sign Out

    func test_signOutTapped_알림표시() async {
        let store = TestStore(initialState: ProfileFeature.State()) {
            ProfileFeature()
        }

        await store.send(.signOutTapped) {
            $0.showSignOutAlert = true
        }
    }

    func test_dismissSignOutAlert_알림숨김() async {
        var initial = ProfileFeature.State()
        initial.showSignOutAlert = true

        let store = TestStore(initialState: initial) { ProfileFeature() }

        await store.send(.dismissSignOutAlert) {
            $0.showSignOutAlert = false
        }
    }

    func test_confirmSignOut_authClient_signOut_호출후_delegate발행() async {
        let signOutCalled = LockIsolated(false)
        var initial = ProfileFeature.State()
        initial.showSignOutAlert = true

        let store = TestStore(initialState: initial) {
            ProfileFeature()
        } withDependencies: {
            $0.authClient.signOut = { signOutCalled.setValue(true) }
        }

        await store.send(.confirmSignOut) {
            $0.showSignOutAlert = false
        }
        await store.receive(\.delegate)

        XCTAssertTrue(signOutCalled.value)
    }

    // MARK: - Delete Account

    func test_deleteAccountTapped_알림표시() async {
        let store = TestStore(initialState: ProfileFeature.State()) {
            ProfileFeature()
        }

        await store.send(.deleteAccountTapped) {
            $0.showDeleteAlert = true
        }
    }

    func test_confirmDeleteAccount_authClient_delete_호출후_delegate발행() async {
        let deleted = LockIsolated(false)
        var initial = ProfileFeature.State()
        initial.showDeleteAlert = true

        let store = TestStore(initialState: initial) {
            ProfileFeature()
        } withDependencies: {
            $0.authClient.deleteAccount = { deleted.setValue(true) }
        }

        await store.send(.confirmDeleteAccount) {
            $0.showDeleteAlert = false
        }
        await store.receive(\.delegate)

        XCTAssertTrue(deleted.value)
    }

    // MARK: - Nickname Change Sheet

    func test_changeNicknameTapped_현재닉네임으로_초기화() async {
        var initial = ProfileFeature.State()
        initial.userProfile.nickname = "별지기"

        let store = TestStore(initialState: initial) { ProfileFeature() }

        await store.send(.changeNicknameTapped) {
            $0.nicknameState = NicknameFeature.State(nickname: "별지기", isOnboarding: false)
            $0.showNicknameChange = true
        }
    }

    func test_changeNicknameTapped_닉네임없으면_빈문자열() async {
        let store = TestStore(initialState: ProfileFeature.State()) {
            ProfileFeature()
        }

        await store.send(.changeNicknameTapped) {
            $0.nicknameState = NicknameFeature.State(nickname: "", isOnboarding: false)
            $0.showNicknameChange = true
        }
    }

    func test_nickname_delegate_nicknameSet_시트닫힘() async {
        var initial = ProfileFeature.State()
        initial.showNicknameChange = true

        let store = TestStore(initialState: initial) { ProfileFeature() }
        // 자식 reducer 내부 효과는 관심사가 아님
        store.exhaustivity = .off

        await store.send(.nickname(.delegate(.nicknameSet))) {
            $0.showNicknameChange = false
        }
    }

    func test_dismissNicknameChange_시트닫힘() async {
        var initial = ProfileFeature.State()
        initial.showNicknameChange = true

        let store = TestStore(initialState: initial) { ProfileFeature() }

        await store.send(.dismissNicknameChange) {
            $0.showNicknameChange = false
        }
    }
}
