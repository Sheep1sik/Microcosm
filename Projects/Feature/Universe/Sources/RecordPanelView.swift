import SwiftUI
import ComposableArchitecture
import DomainEntity

struct RecordPanelView: View {
    @Bindable var store: StoreOf<UniverseFeature>
    let scene: UniverseScene
    @FocusState.Binding var isTextFocused: Bool

    init(store: StoreOf<UniverseFeature>, scene: UniverseScene, isTextFocused: FocusState<Bool>.Binding) {
        self.store = store
        self.scene = scene
        self._isTextFocused = isTextFocused
    }

    var body: some View {
        let remaining = store.remainingRecordCount
        VStack(spacing: 12) {
            if store.onboardingStep != .createStarPrompt {
                Text("오늘 남은 기록 \(remaining)/\(UniverseFeature.State.dailyRecordLimit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        remaining <= 1 ? .red :
                        remaining <= 3 ? .orange :
                        .white.opacity(0.5)
                    )
            }

            HStack(spacing: 8) {
                Text("✦").foregroundStyle(.white.opacity(0.6))
                TextField("별 이름", text: $store.starName)
                    .foregroundStyle(.white)
                    .focused($isTextFocused)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                TextField("기록 내용", text: $store.recordContent, axis: .vertical)
                    .foregroundStyle(.white)
                    .focused($isTextFocused)
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    store.send(.saveRecord)
                } label: {
                    Group {
                        if store.isAnalyzingColor {
                            ProgressView().tint(.white)
                        } else {
                            Text("새기기")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(
                            store.recordContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.white.opacity(0.15)
                                : Color(red: 0.55, green: 0.83, blue: 0.97)
                        )
                    )
                }
                .disabled(store.recordContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isAnalyzingColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    Color(red: 0.01, green: 0.02, blue: 0.04).opacity(0.6),
                    Color(red: 0.01, green: 0.02, blue: 0.04).opacity(0.92),
                    Color(red: 0.01, green: 0.02, blue: 0.04),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .padding(.top, -40)
        )
    }
}
