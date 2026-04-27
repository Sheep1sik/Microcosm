import SwiftUI
import ComposableArchitecture
import DomainClient
import DomainEntity
import SharedDesignSystem

public struct NicknameInputView: View {
    @Bindable var store: StoreOf<NicknameFeature>
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    public init(store: StoreOf<NicknameFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
                .onTapGesture { isFocused = false }

            VStack(spacing: 32) {
                // 뒤로가기 버튼 (닉네임 변경 모드)
                if !store.isOnboarding {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .medium))
                                Text("돌아가기")
                                    .font(.system(size: 16))
                            }
                            .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                VStack(spacing: 8) {
                    Text(store.isOnboarding ? "닉네임을 정해주세요" : "닉네임 변경")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text("우주에서 사용할 이름이에요")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, store.isOnboarding ? 60 : 20)

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        TextField("", text: Binding(
                            get: { store.nickname },
                            set: { store.send(.nicknameChanged($0)) }
                        ))
                        .placeholder(when: store.nickname.isEmpty) {
                            Text("2~10자")
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .foregroundStyle(.white)
                        .font(.system(size: 18))
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { store.send(.checkNickname) }

                        Button {
                            store.send(.checkNickname)
                        } label: {
                            Group {
                                if store.isChecking {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("중복확인")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    canCheck
                                        ? AppColors.accent.opacity(0.6)
                                        : Color.white.opacity(0.08)
                                )
                            )
                        }
                        .disabled(!canCheck || store.isChecking)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 32)

                    if let message = store.errorMessage {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.8))
                            .transition(.opacity)
                    } else if store.isAvailable == true {
                        Text("사용 가능한 닉네임이에요!")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.accent)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: store.errorMessage)
                .animation(.easeInOut(duration: 0.2), value: store.isAvailable)

                Spacer()

                if store.isAvailable == true {
                    Button {
                        store.send(.confirmTapped)
                    } label: {
                        Group {
                            if store.isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Text("확인").fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accent)
                        )
                    }
                    .disabled(store.isSaving)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .onAppear { isFocused = true }
    }

    private var canCheck: Bool {
        let trimmed = store.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 10
    }

    private var borderColor: Color {
        if store.errorMessage != nil {
            return .red.opacity(0.5)
        } else if store.isAvailable == true {
            return AppColors.accent.opacity(0.5)
        }
        return Color.white.opacity(0.08)
    }
}

private extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
