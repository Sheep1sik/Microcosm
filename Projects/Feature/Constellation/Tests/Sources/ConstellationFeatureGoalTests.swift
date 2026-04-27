import XCTest
import ComposableArchitecture
@testable import FeatureConstellation
import DomainEntity

@MainActor
final class ConstellationFeatureGoalTests: XCTestCase {

    // MARK: - dismissGoalPanel

    func test_dismissGoalPanel_패널상태_초기화() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                selectedStarIndex: 2,
                showGoalPanel: true,
                isEditingGoal: true
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.dismissGoalPanel) {
            $0.showGoalPanel = false
            $0.selectedStarIndex = nil
            $0.isEditingGoal = false
        }
    }

    // MARK: - startNewGoal

    func test_startNewGoal_편집상태_신규입력() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                isEditingGoal: false,
                editingGoalId: "old-id",
                goalTitle: "old",
                editingSubGoals: [SubGoal(title: "sub")]
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.startNewGoal) {
            $0.isEditingGoal = true
            $0.editingGoalId = nil
            $0.goalTitle = ""
            $0.editingSubGoals = []
        }
    }

    // MARK: - startEditGoal

    func test_startEditGoal_기존목표_편집상태로_로딩() async {
        let subs = [SubGoal(title: "s1"), SubGoal(title: "s2")]
        let goal = Goal(
            id: "g1",
            constellationId: "ORI",
            starIndex: 0,
            title: "기존 목표",
            subGoals: subs
        )
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }

        await store.send(.startEditGoal(goal)) {
            $0.isEditingGoal = true
            $0.editingGoalId = "g1"
            $0.goalTitle = "기존 목표"
            $0.editingSubGoals = subs
        }
    }

    // MARK: - goalTitleChanged

    func test_goalTitleChanged_타이틀만_반영() async {
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }

        await store.send(.goalTitleChanged("신규 타이틀")) {
            $0.goalTitle = "신규 타이틀"
        }
    }

    // MARK: - addSubGoal / removeSubGoal / subGoalTitleChanged

    func test_addSubGoal_빈_서브골_추가() async {
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }
        // SubGoal 의 id 는 UUID 로 자동 생성되어 결정론적 비교가 어렵다.
        // 대신 append 결과를 직접 검증한다.
        store.exhaustivity = .off

        await store.send(.addSubGoal)
        XCTAssertEqual(store.state.editingSubGoals.count, 1)
        XCTAssertEqual(store.state.editingSubGoals.first?.title, "")
    }

    func test_removeSubGoal_해당id_제거() async {
        let s1 = SubGoal(id: "s1", title: "a")
        let s2 = SubGoal(id: "s2", title: "b")
        let store = TestStore(
            initialState: ConstellationFeature.State(
                editingSubGoals: [s1, s2]
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.removeSubGoal("s1")) {
            $0.editingSubGoals = [s2]
        }
    }

    func test_subGoalTitleChanged_해당id_타이틀_갱신() async {
        let s1 = SubGoal(id: "s1", title: "old")
        let store = TestStore(
            initialState: ConstellationFeature.State(
                editingSubGoals: [s1]
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.subGoalTitleChanged(id: "s1", title: "new")) {
            $0.editingSubGoals[0].title = "new"
        }
    }

    // MARK: - saveGoal

    func test_saveGoal_선택정보없음_무시() async {
        // selectedConstellationId 또는 selectedStarIndex 가 nil 이면 guard 로 early return.
        let store = TestStore(
            initialState: ConstellationFeature.State(
                goalTitle: "제목"
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.saveGoal)
    }

    func test_saveGoal_빈_타이틀_무시() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                selectedConstellationId: "ORI",
                selectedStarIndex: 0,
                goalTitle: "   "
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.saveGoal)
    }

    func test_saveGoal_신규목표_편집상태_초기화_패널닫기() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                selectedConstellationId: "ORI",
                selectedStarIndex: 0,
                showGoalPanel: true,
                isEditingGoal: true,
                goalTitle: "  새 목표  ",
                editingSubGoals: [SubGoal(title: "s1"), SubGoal(title: "")]
            )
        ) {
            ConstellationFeature()
        } withDependencies: {
            // goalClient.addGoal effect 는 authClient.currentUser()?.uid == nil 로 early return.
            $0.authClient.currentUser = { nil }
        }
        store.exhaustivity = .off

        await store.send(.saveGoal) {
            $0.isEditingGoal = false
            $0.editingGoalId = nil
            $0.goalTitle = ""
            $0.editingSubGoals = []
            $0.showGoalPanel = false
            $0.selectedStarIndex = nil
        }
    }

    // MARK: - goalSaved / goalDeleted

    func test_goalSaved_가이드registerGoal일때_closing으로_전환() async {
        var state = ConstellationFeature.State()
        state.guideStep = .registerGoal
        let store = TestStore(
            initialState: state
        ) {
            ConstellationFeature()
        }

        await store.send(.goalSaved) {
            $0.guideStep = .closing
        }
    }

    func test_goalSaved_가이드아님_상태변경없음() async {
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }

        await store.send(.goalSaved)
    }

    func test_goalDeleted_패널_편집상태_초기화() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                selectedStarIndex: 1,
                showGoalPanel: true,
                isEditingGoal: true
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.goalDeleted) {
            $0.showGoalPanel = false
            $0.selectedStarIndex = nil
            $0.isEditingGoal = false
        }
    }

    // MARK: - toggleGoalCompletion

    func test_toggleGoalCompletion_미완료목표_완료로_전환_패널닫기() async {
        let goal = Goal(
            id: "g1",
            constellationId: "ORI",
            starIndex: 0,
            title: "t1"
        )
        let store = TestStore(
            initialState: ConstellationFeature.State(
                allGoals: [goal],
                selectedStarIndex: 0,
                showGoalPanel: true
            )
        ) {
            ConstellationFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
        }
        // completedAt = .now 는 결정론적 비교가 어렵고, 업데이트 effect 는 관심 밖.
        store.exhaustivity = .off

        await store.send(.toggleGoalCompletion(goalId: "g1"))
        XCTAssertNotNil(store.state.allGoals[0].completedAt)
        XCTAssertFalse(store.state.showGoalPanel)
        XCTAssertNil(store.state.selectedStarIndex)
    }

    func test_toggleGoalCompletion_완료목표_미완료로_토글() async {
        let goal = Goal(
            id: "g1",
            constellationId: "ORI",
            starIndex: 0,
            title: "t1",
            completedAt: .now
        )
        let store = TestStore(
            initialState: ConstellationFeature.State(
                allGoals: [goal]
            )
        ) {
            ConstellationFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
        }
        store.exhaustivity = .off

        await store.send(.toggleGoalCompletion(goalId: "g1"))
        XCTAssertNil(store.state.allGoals[0].completedAt)
    }

    func test_toggleGoalCompletion_존재하지않는id_무시() async {
        let store = TestStore(
            initialState: ConstellationFeature.State()
        ) {
            ConstellationFeature()
        }

        await store.send(.toggleGoalCompletion(goalId: "unknown"))
    }

    // MARK: - toggleSubGoal

    func test_toggleSubGoal_서브골_토글() async {
        let s1 = SubGoal(id: "s1", title: "a", isCompleted: false)
        let s2 = SubGoal(id: "s2", title: "b", isCompleted: false)
        let goal = Goal(
            id: "g1",
            constellationId: "ORI",
            starIndex: 0,
            title: "t1",
            subGoals: [s1, s2]
        )
        let store = TestStore(
            initialState: ConstellationFeature.State(
                allGoals: [goal]
            )
        ) {
            ConstellationFeature()
        } withDependencies: {
            $0.authClient.currentUser = { nil }
        }
        store.exhaustivity = .off

        await store.send(.toggleSubGoal(goalId: "g1", subGoalId: "s1"))
        XCTAssertTrue(store.state.allGoals[0].subGoals[0].isCompleted)
        XCTAssertFalse(store.state.allGoals[0].subGoals[1].isCompleted)
    }

    // MARK: - cancelEdit

    func test_cancelEdit_편집입력_초기화() async {
        let store = TestStore(
            initialState: ConstellationFeature.State(
                isEditingGoal: true,
                editingGoalId: "g1",
                goalTitle: "작성중",
                editingSubGoals: [SubGoal(title: "s")]
            )
        ) {
            ConstellationFeature()
        }

        await store.send(.cancelEdit) {
            $0.isEditingGoal = false
            $0.editingGoalId = nil
            $0.goalTitle = ""
            $0.editingSubGoals = []
        }
    }
}
