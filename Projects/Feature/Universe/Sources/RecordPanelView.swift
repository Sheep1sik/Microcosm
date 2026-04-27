import SwiftUI
import ComposableArchitecture
import DomainEntity
import SharedDesignSystem

struct RecordPanelView: View {
    @Bindable var store: StoreOf<UniverseFeature>
    let scene: UniverseScene
    @FocusState.Binding var isTextFocused: Bool

    init(store: StoreOf<UniverseFeature>, scene: UniverseScene, isTextFocused: FocusState<Bool>.Binding) {
        self.store = store
        self.scene = scene
        self._isTextFocused = isTextFocused
    }

    private static let freeCharLimit = 100

    private var contentLength: Int {
        store.recordContent.count
    }

    private var isOverLimit: Bool {
        contentLength > Self.freeCharLimit
    }

    var body: some View {
        let remaining = store.remainingRecordCount
        let contentEmpty = store.recordContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        VStack(spacing: 10) {
            if store.onboarding.step != .createStarPrompt {
                Text("오늘 남은 기록 \(remaining)/\(UniverseFeature.State.dailyRecordLimit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        remaining <= 1 ? .red :
                        remaining <= 3 ? .orange :
                        .white.opacity(0.5)
                    )
            }

            // 별 이름 + 새기기 버튼
            HStack(spacing: 8) {
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
                            (contentEmpty || isOverLimit)
                                ? Color.white.opacity(0.15)
                                : AppColors.accent
                        )
                    )
                }
                .disabled(contentEmpty || isOverLimit || store.isAnalyzingColor)
            }

            // 기록 내용 (전체 너비)
            VStack(alignment: .trailing, spacing: 4) {
                TextField("기록 내용", text: $store.recordContent, axis: .vertical)
                    .foregroundStyle(.white)
                    .focused($isTextFocused)
                    .font(.subheadline)
                    .lineLimit(3...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("\(contentLength)/\(Self.freeCharLimit)")
                    .font(.system(size: 10))
                    .foregroundStyle(isOverLimit ? .red.opacity(0.8) : .white.opacity(0.3))
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    AppColors.surfaceDark.opacity(0.6),
                    AppColors.surfaceDark.opacity(0.92),
                    AppColors.surfaceDark,
                ],
                startPoint: .top, endPoint: .bottom
            )
            .padding(.top, -40)
        )
    }
}
