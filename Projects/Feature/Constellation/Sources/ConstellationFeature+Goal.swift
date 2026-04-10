import ComposableArchitecture
import DomainEntity

extension ConstellationFeature {
    /// 목표 패널 / CRUD / 완료 토글 / 편집 취소 처리.
    func reduceGoal(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
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
            // 가이드: 목표 등록 완료 → 축하 단계
            if state.guideStep == .registerGoal {
                state.guideStep = .closing
            }
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

        default:
            return .none
        }
    }
}
