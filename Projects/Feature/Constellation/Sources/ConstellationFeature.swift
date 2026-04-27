import ComposableArchitecture
import DomainEntity
import DomainClient
import Foundation

@Reducer
public struct ConstellationFeature {
    @ObservableState
    public struct State: Equatable {
        // Goals
        public var allGoals: [Goal] = []

        // Scene State
        public var selectedConstellationId: String?
        public var selectedStarIndex: Int?
        public var isInConstellationDetail = false

        // Goal Panel
        public var showGoalPanel = false

        // Goal Editing
        public var isEditingGoal = false
        public var editingGoalId: String?        // nil = 새 목표, non-nil = 수정
        public var goalTitle = ""
        public var editingSubGoals: [SubGoal] = []

        // Constellation Completion
        public var completedConstellationMessage: String?
        public var completedConstellationSubtitle: String?
        public var previouslyCompletedIds: Set<String> = []
        public var hasInitialGoalsLoaded = false

        // Guide
        public var showGuide = false
        public var guideStep: GuideStep?
        /// Firestore `users/{uid}.hasSeenConstellationGuide` 와 동기화되는 1회 노출 플래그.
        /// RootFeature → MainTabFeature → 여기로 푸시된다.
        public var hasSeenConstellationGuide = false
        public var userDisplayName: String?

        public enum GuideStep: Int, Equatable, CaseIterable {
            case welcome = 0         // 환영 (탭하여 계속)
            case tapConstellation    // "별자리를 탭해보세요" (유저가 직접 탭)
            case tapStar             // "별을 탭해보세요" (유저가 직접 탭)
            case registerGoal        // "목표를 등록해보세요" (유저가 직접 저장)
            case closing             // 축하 메시지 (탭하여 완료)
        }

        // Search
        public var isSearching = false
        public var searchText = ""
        public var searchResults: [ConstellationDefinition] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return ConstellationCatalog.all }
            return ConstellationCatalog.all.filter {
                $0.nameKO.contains(query) ||
                $0.nameEN.localizedCaseInsensitiveContains(query) ||
                $0.id.localizedCaseInsensitiveContains(query)
            }
        }

        // Navigation (View에서 scene 메서드 호출용)
        public var pendingNavigation: PendingNavigation?

        public enum PendingNavigation: Equatable {
            case zoomToConstellation(String)
        }

        // Computed: 선택된 별의 목표들
        public var selectedStarGoals: [Goal] {
            guard let cId = selectedConstellationId,
                  let sIdx = selectedStarIndex else { return [] }
            return allGoals.filter { $0.constellationId == cId && $0.starIndex == sIdx }
        }

        public init(
            allGoals: [Goal] = [],
            selectedConstellationId: String? = nil,
            selectedStarIndex: Int? = nil,
            isInConstellationDetail: Bool = false,
            showGoalPanel: Bool = false,
            isEditingGoal: Bool = false,
            editingGoalId: String? = nil,
            goalTitle: String = "",
            editingSubGoals: [SubGoal] = [],
            pendingNavigation: PendingNavigation? = nil,
            isSearching: Bool = false,
            searchText: String = ""
        ) {
            self.allGoals = allGoals
            self.selectedConstellationId = selectedConstellationId
            self.selectedStarIndex = selectedStarIndex
            self.isInConstellationDetail = isInConstellationDetail
            self.showGoalPanel = showGoalPanel
            self.isEditingGoal = isEditingGoal
            self.editingGoalId = editingGoalId
            self.goalTitle = goalTitle
            self.editingSubGoals = editingSubGoals
            self.pendingNavigation = pendingNavigation
            self.isSearching = isSearching
            self.searchText = searchText
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // Lifecycle
        case onAppear

        // Data
        case goalsUpdated([Goal])

        // Scene Callbacks
        case sceneDidEnterConstellationDetail(id: String)
        case sceneDidExitConstellationDetail
        case sceneDidTapStar(constellationId: String, starIndex: Int)
        case sceneDidTapEmptyArea

        // Goal Panel
        case dismissGoalPanel

        // Goal CRUD
        case startNewGoal
        case startEditGoal(Goal)
        case goalTitleChanged(String)
        case addSubGoal
        case removeSubGoal(String)
        case subGoalTitleChanged(id: String, title: String)
        case saveGoal
        case deleteGoal(String)
        case goalSaved
        case goalDeleted

        // Goal/SubGoal Toggle
        case toggleGoalCompletion(goalId: String)
        case toggleAllSubGoals(goalId: String)
        case toggleSubGoal(goalId: String, subGoalId: String)

        // Edit Cancel
        case cancelEdit

        // Constellation Completion
        case dismissCompletionMessage

        // Guide
        case checkGuide
        case advanceGuide
        case dismissGuide

        // Search
        case toggleSearch
        case searchTextChanged(String)
        case selectSearchResult(String)
    }

    @Dependency(\.goalClient) var goalClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.userClient) var userClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        // 데이터 갱신 / 별자리 완성 메시지 닫기처럼 그룹화하기 애매한 소규모 액션은 inline 처리.
        Reduce { state, action in
            switch action {
            case .goalsUpdated(let goals):
                state.allGoals = goals
                return .none

            case .dismissCompletionMessage:
                state.completedConstellationMessage = nil
                state.completedConstellationSubtitle = nil
                return .none

            default:
                return .none
            }
        }

        // 기능별 분할 reduce. 각 블록은 extension 파일에 정의되어 있으며
        // 매칭되지 않는 액션은 default → .none 으로 흘려보낸다.
        // - ConstellationFeature+SceneCallbacks.swift
        // - ConstellationFeature+Goal.swift
        // - ConstellationFeature+Guide.swift
        // - ConstellationFeature+Search.swift
        Reduce { state, action in
            reduceSceneCallbacks(into: &state, action: action)
        }
        Reduce { state, action in
            reduceGoal(into: &state, action: action)
        }
        Reduce { state, action in
            reduceGuide(into: &state, action: action)
        }
        Reduce { state, action in
            reduceSearch(into: &state, action: action)
        }
    }

    // MARK: - Constellation Completion Check

    public struct CompletionChange: Equatable {
        public var newlyCompleted: String?
        public var newlyLost: String?
    }

    /// 별자리 완성/해제 변화를 감지
    /// 조건: 별자리의 모든 별에 최소 하나의 목표가 있고, 모든 목표가 완료되어야 완성
    public static func checkConstellationCompletion(
        goals: [Goal],
        previouslyCompletedIds: inout Set<String>
    ) -> CompletionChange {
        var change = CompletionChange()

        for def in ConstellationCatalog.all {
            let cGoals = goals.filter { $0.constellationId == def.id }

            // 목표가 없는 별자리 → 이전에 완성이었다면 빛을 잃음
            if cGoals.isEmpty {
                if previouslyCompletedIds.contains(def.id) {
                    previouslyCompletedIds.remove(def.id)
                    change.newlyLost = def.id
                }
                continue
            }

            // 모든 별에 최소 하나의 목표가 있는지 확인
            let allStarIndices = Set(def.stars.map(\.index))
            let starIndicesWithGoals = Set(cGoals.map(\.starIndex))
            let allStarsHaveGoals = allStarIndices.isSubset(of: starIndicesWithGoals)

            // 모든 별에 목표가 있고, 모든 목표가 완료되었는지
            let allCompleted = allStarsHaveGoals && cGoals.allSatisfy(\.isCompleted)

            if allCompleted && !previouslyCompletedIds.contains(def.id) {
                previouslyCompletedIds.insert(def.id)
                change.newlyCompleted = def.id
            } else if !allCompleted && previouslyCompletedIds.contains(def.id) {
                previouslyCompletedIds.remove(def.id)
                change.newlyLost = def.id
            }
        }
        return change
    }
}
