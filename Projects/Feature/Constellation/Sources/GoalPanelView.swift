import SwiftUI
import ComposableArchitecture
import DomainEntity

struct GoalPanelView: View {
    let store: StoreOf<ConstellationFeature>

    private var starInfo: (constellationName: String, starName: String?) {
        guard let cId = store.selectedConstellationId,
              let sIdx = store.selectedStarIndex,
              let def = ConstellationCatalog.find(cId) else {
            return ("", nil)
        }
        let star = def.stars.first { $0.index == sIdx }
        return (def.nameKO, star?.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // 핸들 바
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                // 헤더
                VStack(spacing: 4) {
                    Text(starInfo.constellationName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    if let name = starInfo.starName {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(.white)
                    } else if let idx = store.selectedStarIndex {
                        Text("별 \(idx + 1)")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // 목표 리스트
                if store.selectedStarGoals.isEmpty {
                    VStack(spacing: 8) {
                        Text("등록된 목표가 없습니다")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("목표를 추가하여 별에 빛을 더해보세요")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.selectedStarGoals) { goal in
                                GoalRowView(goal: goal, store: store)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 280)
                }

                // 목표 추가 버튼
                Button {
                    store.send(.startNewGoal)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("목표 추가")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.55, green: 0.83, blue: 0.97))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.55, green: 0.83, blue: 0.97).opacity(0.1))
                    )
                }

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.04, green: 0.06, blue: 0.09).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Goal Row

private struct GoalRowView: View {
    let goal: Goal
    let store: StoreOf<ConstellationFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    if !goal.subGoals.isEmpty {
                        Text("\(goal.subGoals.filter(\.isCompleted).count)/\(goal.subGoals.count) 완료")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        Text(goal.isCompleted ? "완료됨" : "미완료")
                            .font(.caption)
                            .foregroundStyle(goal.isCompleted
                                ? Color(red: 0.3, green: 0.85, blue: 0.5).opacity(0.7)
                                : .white.opacity(0.4))
                    }
                }

                Spacer()

                // 진행률 링 또는 완료 토글
                if goal.subGoals.isEmpty {
                    Button {
                        store.send(.toggleGoalCompletion(goalId: goal.id))
                    } label: {
                        Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(
                                goal.isCompleted
                                    ? Color(red: 0.3, green: 0.85, blue: 0.5)
                                    : .white.opacity(0.3)
                            )
                    }
                } else {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: goal.completionRatio)
                            .stroke(
                                goal.isCompleted
                                    ? Color(red: 0.3, green: 0.85, blue: 0.5)
                                    : Color(red: 0.55, green: 0.83, blue: 0.97),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 28, height: 28)
                }

                // 편집/삭제 메뉴
                Menu {
                    Button {
                        store.send(.startEditGoal(goal))
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        store.send(.deleteGoal(goal.id))
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 30, height: 30)
                }
            }

            // 체크리스트
            if !goal.subGoals.isEmpty {
                VStack(spacing: 6) {
                    ForEach(goal.subGoals) { subGoal in
                        Button {
                            store.send(.toggleSubGoal(goalId: goal.id, subGoalId: subGoal.id))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: subGoal.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline)
                                    .foregroundStyle(
                                        subGoal.isCompleted
                                            ? Color(red: 0.3, green: 0.85, blue: 0.5)
                                            : .white.opacity(0.3)
                                    )

                                Text(subGoal.title)
                                    .font(.caption)
                                    .foregroundStyle(
                                        subGoal.isCompleted
                                            ? .white.opacity(0.4)
                                            : .white.opacity(0.7)
                                    )
                                    .strikethrough(subGoal.isCompleted, color: .white.opacity(0.3))

                                Spacer()
                            }
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }
}
