import SwiftUI
import ComposableArchitecture
import DomainEntity
import SharedDesignSystem

struct GoalEditView: View {
    let store: StoreOf<ConstellationFeature>
    @FocusState private var focusedSubGoalId: String?

    private var isEditing: Bool { store.editingGoalId != nil }
    private var canSave: Bool {
        !store.goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            panelContent
        }
        .onChange(of: store.editingSubGoals.count) {
            if let last = store.editingSubGoals.last, last.title.isEmpty {
                focusedSubGoalId = last.id
            }
        }
    }

    private var panelContent: some View {
        VStack(spacing: 16) {
            handleBar
            headerBar
            divider
            goalTitleSection
            subGoalSection
            Spacer().frame(height: 8)
        }
        .padding(.horizontal, 20)
        .background(panelBackground)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.white.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
    }

    private var headerBar: some View {
        HStack {
            Button("취소") {
                store.send(.cancelEdit)
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Text(isEditing ? "목표 수정" : "새 목표")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Button("저장") {
                store.send(.saveGoal)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(canSave ? AppColors.accent : .white.opacity(0.3))
            .disabled(!canSave)
        }
    }

    private var divider: some View {
        Divider().background(Color.white.opacity(0.1))
    }

    private var goalTitleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("목표")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            TextField("", text: Binding(
                get: { store.goalTitle },
                set: { store.send(.goalTitleChanged($0)) }
            ), prompt: Text("목표를 입력하세요").foregroundStyle(.white.opacity(0.25)))
                .font(.body)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                )
        }
    }

    private var subGoalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("체크리스트")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Button {
                    store.send(.addSubGoal)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)
                }
            }

            if store.editingSubGoals.isEmpty {
                Text("체크리스트를 추가하면 별이 점점 밝아집니다")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 8)
            } else {
                subGoalList
            }
        }
    }

    private var subGoalList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(store.editingSubGoals) { subGoal in
                    subGoalRow(subGoal)
                }
            }
        }
        .frame(maxHeight: 200)
    }

    private func subGoalRow(_ subGoal: SubGoal) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.2))

            TextField("", text: Binding(
                get: { subGoal.title },
                set: { store.send(.subGoalTitleChanged(id: subGoal.id, title: $0)) }
            ), prompt: Text("항목 입력").foregroundStyle(.white.opacity(0.2)))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .tint(.white)
                .focused($focusedSubGoalId, equals: subGoal.id)

            Button {
                store.send(.removeSubGoal(subGoal.id))
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(AppColors.surfaceElevated.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }
}
