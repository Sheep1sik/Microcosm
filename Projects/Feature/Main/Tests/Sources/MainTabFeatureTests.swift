import XCTest
import ComposableArchitecture
@testable import FeatureMain
import FeatureUniverse
import FeatureConstellation
import FeatureProfile
import DomainEntity

@MainActor
final class MainTabFeatureTests: XCTestCase {

    // MARK: - tabSelected

    func test_tabSelected_상태반영() async {
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        await store.send(.tabSelected(.constellation)) {
            $0.selectedTab = .constellation
        }
        await store.send(.tabSelected(.profile)) {
            $0.selectedTab = .profile
        }
        await store.send(.tabSelected(.universe)) {
            $0.selectedTab = .universe
        }
    }

    // MARK: - recordsUpdated

    func test_recordsUpdated_universe와_profile에_동시전파() async {
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }
        let records = [Record(content: "a"), Record(content: "b")]

        await store.send(.recordsUpdated(records)) {
            $0.universe.allRecords = records
            $0.profile.allRecords = records
        }
    }

    func test_recordsUpdated_constellation_userDisplayName_universe에서_복사() async {
        // Root → MainTab → Universe 에 닉네임이 들어온 뒤,
        // recordsUpdated 트리거 시 Constellation 도 동일 닉네임을 가져야 함.
        var initial = MainTabFeature.State()
        initial.universe.userDisplayName = "별지기"

        let store = TestStore(initialState: initial) { MainTabFeature() }

        await store.send(.recordsUpdated([])) {
            $0.constellation.userDisplayName = "별지기"
        }
    }

    // MARK: - goalsUpdated (초기 로드)

    func test_goalsUpdated_초기로드는_메시지_미생성() async {
        // 첫 goalsUpdated 는 hasInitialGoalsLoaded 를 true 로 올리고
        // 완성 메시지는 띄우지 않는다 (앱 진입 시 완성된 별자리가 깜빡이는 것 방지).
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // CMi 는 별 2개(index 0,1) — 두 별 모두 완성된 목표가 있으면 별자리 완성.
        let goals = [
            Self.completedGoal(constellationId: "CMi", starIndex: 0),
            Self.completedGoal(constellationId: "CMi", starIndex: 1),
        ]

        await store.send(.goalsUpdated(goals)) {
            $0.constellation.allGoals = goals
            $0.constellation.hasInitialGoalsLoaded = true
            $0.constellation.previouslyCompletedIds = ["CMi"]
            $0.universe.completedConstellationIds = ["CMi"]
            // 메시지는 생성되지 않음 (isFromObserver + 첫 로드)
        }
    }

    // MARK: - goalsUpdated (후속 갱신)

    func test_goalsUpdated_초기로드후_새완성_메시지생성() async {
        // 사전 조건: 초기 로드는 이미 끝났고, 아직 완성된 별자리는 없음.
        var initial = MainTabFeature.State()
        initial.constellation.hasInitialGoalsLoaded = true
        initial.universe.userDisplayName = "별지기"

        let store = TestStore(initialState: initial) { MainTabFeature() }

        let goals = [
            Self.completedGoal(constellationId: "CMi", starIndex: 0),
            Self.completedGoal(constellationId: "CMi", starIndex: 1),
        ]

        await store.send(.goalsUpdated(goals)) {
            $0.constellation.allGoals = goals
            $0.constellation.previouslyCompletedIds = ["CMi"]
            $0.universe.completedConstellationIds = ["CMi"]
            $0.constellation.completedConstellationMessage = "작은개자리의\n모든 별들이 빛을 찾았어요!"
            $0.constellation.completedConstellationSubtitle = "완성된 별자리는 별지기님의 소우주에서도 볼 수 있어요"
        }
    }

    func test_goalsUpdated_userDisplayName_없으면_기본값_우주인() async {
        var initial = MainTabFeature.State()
        initial.constellation.hasInitialGoalsLoaded = true

        let store = TestStore(initialState: initial) { MainTabFeature() }

        let goals = [
            Self.completedGoal(constellationId: "CMi", starIndex: 0),
            Self.completedGoal(constellationId: "CMi", starIndex: 1),
        ]

        await store.send(.goalsUpdated(goals)) {
            $0.constellation.allGoals = goals
            $0.constellation.previouslyCompletedIds = ["CMi"]
            $0.universe.completedConstellationIds = ["CMi"]
            $0.constellation.completedConstellationMessage = "작은개자리의\n모든 별들이 빛을 찾았어요!"
            $0.constellation.completedConstellationSubtitle = "완성된 별자리는 우주인님의 소우주에서도 볼 수 있어요"
        }
    }

    func test_goalsUpdated_완성됐던별자리_해제시_lostMessage_생성() async {
        // 사전 조건: 이미 CMi가 완성 상태로 기록돼 있음.
        var initial = MainTabFeature.State()
        initial.constellation.hasInitialGoalsLoaded = true
        initial.constellation.previouslyCompletedIds = ["CMi"]
        initial.universe.completedConstellationIds = ["CMi"]

        let store = TestStore(initialState: initial) { MainTabFeature() }

        // 한 별의 목표가 미완료 상태로 갱신되면 별자리는 해제.
        let goals = [
            Self.completedGoal(constellationId: "CMi", starIndex: 0),
            Self.incompleteGoal(constellationId: "CMi", starIndex: 1),
        ]

        await store.send(.goalsUpdated(goals)) {
            $0.constellation.allGoals = goals
            $0.constellation.previouslyCompletedIds = []
            $0.universe.completedConstellationIds = []
            $0.constellation.completedConstellationMessage = "작은개자리의\n별자리가 빛을 잃었어요"
            $0.constellation.completedConstellationSubtitle = "목표를 다시 달성하면 별자리가 빛을 되찾아요"
        }
    }

    // MARK: - 낙관적 업데이트 경로 (constellation 액션 → recomputeCompletion)

    func test_constellation_toggleGoalCompletion_초기로드후_완성메시지_생성() async {
        // 사전 조건:
        // - 초기 goalsUpdated 가 끝난 상태(hasInitialGoalsLoaded = true)
        // - 두 별 모두 미완료 상태인 CMi 목표가 이미 state 에 있음
        // 액션: 두 번째 별 목표가 완료 상태로 toggle (낙관적)
        // 검증: recomputeCompletion 이 호출되어 완성 메시지 생성
        var initial = MainTabFeature.State()
        initial.constellation.hasInitialGoalsLoaded = true
        initial.universe.userDisplayName = "별지기"
        // 액션은 단순 트리거이므로 allGoals 자체는 이미 완성 상태로 둔다.
        // (ConstellationFeature.toggleGoalCompletion 의 실제 변환 로직은 별도 테스트 영역.)
        initial.constellation.allGoals = [
            Self.completedGoal(constellationId: "CMi", starIndex: 0),
            Self.completedGoal(constellationId: "CMi", starIndex: 1),
        ]

        let store = TestStore(initialState: initial) { MainTabFeature() }
        // 자식 reducer 는 본 테스트 관심사가 아니므로 비활성.
        store.exhaustivity = .off

        await store.send(.constellation(.toggleGoalCompletion(goalId: "ignored"))) {
            $0.constellation.previouslyCompletedIds = ["CMi"]
            $0.universe.completedConstellationIds = ["CMi"]
            $0.constellation.completedConstellationMessage = "작은개자리의\n모든 별들이 빛을 찾았어요!"
            $0.constellation.completedConstellationSubtitle = "완성된 별자리는 별지기님의 소우주에서도 볼 수 있어요"
        }
    }

    func test_constellation_낙관적토글_초기로드전이면_메시지없음() async {
        // hasInitialGoalsLoaded == false 인 시점에 낙관적 토글이 들어오면
        // shouldEmitMessage 는 false 라 메시지가 생성되지 않아야 한다.
        var initial = MainTabFeature.State()
        initial.constellation.hasInitialGoalsLoaded = false
        initial.constellation.allGoals = [
            Self.completedGoal(constellationId: "CMi", starIndex: 0),
            Self.completedGoal(constellationId: "CMi", starIndex: 1),
        ]

        let store = TestStore(initialState: initial) { MainTabFeature() }
        store.exhaustivity = .off

        await store.send(.constellation(.toggleGoalCompletion(goalId: "ignored"))) {
            // 메시지/자막은 nil 유지, 다만 ID 추적 + 배경 표시는 갱신된다.
            $0.constellation.previouslyCompletedIds = ["CMi"]
            $0.universe.completedConstellationIds = ["CMi"]
        }
    }

    // MARK: - completedConstellationIds 계산

    func test_completedConstellationIds_별일부에만_목표있으면_미완성() async {
        var initial = MainTabFeature.State()
        initial.constellation.hasInitialGoalsLoaded = true

        let store = TestStore(initialState: initial) { MainTabFeature() }

        // CMi 는 별 2개 필요한데 index 0 에만 목표 등록.
        let goals = [Self.completedGoal(constellationId: "CMi", starIndex: 0)]

        await store.send(.goalsUpdated(goals)) {
            $0.constellation.allGoals = goals
            // previouslyCompletedIds / completedConstellationIds 모두 비어있는 상태 유지.
        }
    }

    // MARK: - Test Helpers

    private static func completedGoal(constellationId: String, starIndex: Int) -> Goal {
        Goal(
            constellationId: constellationId,
            starIndex: starIndex,
            title: "test-\(constellationId)-\(starIndex)",
            completedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    private static func incompleteGoal(constellationId: String, starIndex: Int) -> Goal {
        Goal(
            constellationId: constellationId,
            starIndex: starIndex,
            title: "incomplete-\(constellationId)-\(starIndex)"
        )
    }
}
