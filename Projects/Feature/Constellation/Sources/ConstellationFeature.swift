import ComposableArchitecture
import DomainEntity
import DomainClient

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

        // Search
        case toggleSearch
        case searchTextChanged(String)
        case selectSearchResult(String)
    }

    @Dependency(\.goalClient) var goalClient
    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            // MARK: - Data

            case .goalsUpdated(let goals):
                state.allGoals = goals
                return .none

            // MARK: - Scene Callbacks

            case .sceneDidEnterConstellationDetail(let id):
                state.isInConstellationDetail = true
                state.selectedConstellationId = id
                return .none

            case .sceneDidExitConstellationDetail:
                state.isInConstellationDetail = false
                state.selectedConstellationId = nil
                state.selectedStarIndex = nil
                state.showGoalPanel = false
                state.isEditingGoal = false
                return .none

            case .sceneDidTapStar(let constellationId, let starIndex):
                state.selectedConstellationId = constellationId
                state.selectedStarIndex = starIndex
                state.showGoalPanel = true
                state.isEditingGoal = false
                return .none

            case .sceneDidTapEmptyArea:
                if state.showGoalPanel && !state.isEditingGoal {
                    state.showGoalPanel = false
                    state.selectedStarIndex = nil
                }
                return .none

            // MARK: - Goal Panel

            case .dismissGoalPanel:
                state.showGoalPanel = false
                state.selectedStarIndex = nil
                state.isEditingGoal = false
                return .none

            // MARK: - Goal CRUD

            case .startNewGoal:
                state.isEditingGoal = true
                state.editingGoalId = nil
                state.goalTitle = ""
                state.editingSubGoals = []
                return .none

            case .startEditGoal(let goal):
                state.isEditingGoal = true
                state.editingGoalId = goal.id
                state.goalTitle = goal.title
                state.editingSubGoals = goal.subGoals
                return .none

            case .goalTitleChanged(let title):
                state.goalTitle = title
                return .none

            case .addSubGoal:
                state.editingSubGoals.append(SubGoal(title: ""))
                return .none

            case .removeSubGoal(let id):
                state.editingSubGoals.removeAll { $0.id == id }
                return .none

            case .subGoalTitleChanged(let id, let title):
                if let idx = state.editingSubGoals.firstIndex(where: { $0.id == id }) {
                    state.editingSubGoals[idx].title = title
                }
                return .none

            case .saveGoal:
                guard let constellationId = state.selectedConstellationId,
                      let starIndex = state.selectedStarIndex else { return .none }
                let trimmedTitle = state.goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return .none }

                let validSubGoals = state.editingSubGoals.filter {
                    !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }

                // 새 목표 vs 수정 구분을 effect 전에 캡처
                let isNew = state.editingGoalId == nil

                let goal: Goal
                if let editingId = state.editingGoalId,
                   var existing = state.allGoals.first(where: { $0.id == editingId }) {
                    // 기존 목표 수정
                    existing.title = trimmedTitle
                    existing.subGoals = validSubGoals
                    // 전부 완료면 completedAt 설정
                    if existing.isCompleted && existing.completedAt == nil {
                        existing.completedAt = .now
                    } else if !existing.isCompleted {
                        existing.completedAt = nil
                    }
                    goal = existing
                } else {
                    // 새 목표 생성
                    goal = Goal(
                        constellationId: constellationId,
                        starIndex: starIndex,
                        title: trimmedTitle,
                        subGoals: validSubGoals
                    )
                }

                state.isEditingGoal = false
                state.editingGoalId = nil
                state.goalTitle = ""
                state.editingSubGoals = []
                state.showGoalPanel = false
                state.selectedStarIndex = nil

                let goalToSave = goal
                return .run { send in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    if isNew {
                        try await goalClient.addGoal(userId, goalToSave)
                    } else {
                        try await goalClient.updateGoal(userId, goalToSave)
                    }
                    await send(.goalSaved)
                }

            case .deleteGoal(let goalId):
                return .run { send in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try await goalClient.deleteGoal(userId, goalId)
                    await send(.goalDeleted)
                }

            case .goalSaved:
                return .none

            case .goalDeleted:
                state.showGoalPanel = false
                state.selectedStarIndex = nil
                state.isEditingGoal = false
                return .none

            // MARK: - Goal/SubGoal Toggle

            case .toggleGoalCompletion(let goalId):
                guard var goal = state.allGoals.first(where: { $0.id == goalId }),
                      let goalIndex = state.allGoals.firstIndex(where: { $0.id == goalId }) else {
                    return .none
                }
                // 서브골 없는 목표의 완료 토글
                if goal.completedAt != nil {
                    goal.completedAt = nil
                } else {
                    goal.completedAt = .now
                }
                // 토글 시 패널 자동 닫기
                state.showGoalPanel = false
                state.selectedStarIndex = nil
                // 낙관적 로컬 업데이트
                state.allGoals[goalIndex] = goal
                let goalToUpdate = goal
                return .run { send in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try await goalClient.updateGoal(userId, goalToUpdate)
                }

            case .toggleAllSubGoals(let goalId):
                guard var goal = state.allGoals.first(where: { $0.id == goalId }),
                      let goalIndex = state.allGoals.firstIndex(where: { $0.id == goalId }),
                      !goal.subGoals.isEmpty else {
                    return .none
                }
                let allCompleted = goal.subGoals.allSatisfy(\.isCompleted)
                for i in goal.subGoals.indices {
                    goal.subGoals[i].isCompleted = !allCompleted
                    goal.subGoals[i].completedAt = allCompleted ? nil : .now
                }
                goal.completedAt = allCompleted ? nil : .now
                if !allCompleted {
                    state.showGoalPanel = false
                    state.selectedStarIndex = nil
                }
                state.allGoals[goalIndex] = goal
                let goalToUpdate = goal
                return .run { send in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try await goalClient.updateGoal(userId, goalToUpdate)
                }

            case .toggleSubGoal(let goalId, let subGoalId):
                guard var goal = state.allGoals.first(where: { $0.id == goalId }),
                      let goalIndex = state.allGoals.firstIndex(where: { $0.id == goalId }),
                      let subIdx = goal.subGoals.firstIndex(where: { $0.id == subGoalId }) else {
                    return .none
                }
                goal.subGoals[subIdx].isCompleted.toggle()
                if goal.subGoals[subIdx].isCompleted {
                    goal.subGoals[subIdx].completedAt = .now
                } else {
                    goal.subGoals[subIdx].completedAt = nil
                }
                // 전부 완료 체크
                if goal.isCompleted && goal.completedAt == nil {
                    goal.completedAt = .now
                    // 모든 서브골 완료 시 패널 자동 닫기
                    state.showGoalPanel = false
                    state.selectedStarIndex = nil
                } else if !goal.isCompleted {
                    goal.completedAt = nil
                }
                // 낙관적 로컬 업데이트
                state.allGoals[goalIndex] = goal
                let goalToUpdate = goal
                return .run { send in
                    guard let userId = authClient.currentUser()?.uid else { return }
                    try await goalClient.updateGoal(userId, goalToUpdate)
                }

            // MARK: - Edit Cancel

            case .cancelEdit:
                state.isEditingGoal = false
                state.editingGoalId = nil
                state.goalTitle = ""
                state.editingSubGoals = []
                return .none

            // MARK: - Constellation Completion

            case .dismissCompletionMessage:
                state.completedConstellationMessage = nil
                state.completedConstellationSubtitle = nil
                return .none

            // MARK: - Search

            case .toggleSearch:
                state.isSearching.toggle()
                if !state.isSearching {
                    state.searchText = ""
                }
                return .none

            case .searchTextChanged(let text):
                state.searchText = text
                return .none

            case .selectSearchResult(let id):
                state.isSearching = false
                state.searchText = ""
                state.pendingNavigation = .zoomToConstellation(id)
                return .none

            case .binding:
                return .none
            }
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
