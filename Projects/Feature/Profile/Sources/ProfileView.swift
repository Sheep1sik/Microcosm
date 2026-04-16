import SwiftUI
import ComposableArchitecture
import DomainClient
import DomainEntity
import FeatureNickname
import SharedDesignSystem

public struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    public init(store: StoreOf<ProfileFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.surfaceDark
                    .ignoresSafeArea()

                StarfieldBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 프로필 헤더
                            VStack(spacing: 12) {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 80, height: 80)
                                    .overlay {
                                        Text(String((store.userProfile.nickname ?? "우").prefix(1)))
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }

                                // 닉네임 + 펜 아이콘
                                Button {
                                    store.send(.changeNicknameTapped)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(store.userProfile.nickname ?? store.displayName ?? "우주인")
                                            .font(.title2).fontWeight(.bold)
                                            .foregroundStyle(.white)
                                        Image(systemName: "pencil.line")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }

                                if !store.userProfile.email.isEmpty {
                                    Text(store.userProfile.email)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                            .padding(.top, 40)

                            // 감정 통계
                            EmotionStatisticsView(records: store.allRecords)

                            // 로그아웃 / 탈퇴하기
                            HStack(spacing: 0) {
                                Button {
                                    store.send(.signOutTapped)
                                } label: {
                                    Text("로그아웃")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.4))
                                }

                                Text(" / ")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.2))

                                Button {
                                    store.send(.deleteAccountTapped)
                                } label: {
                                    Text("탈퇴하기")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.red.opacity(0.4))
                                }
                            }
                            .padding(.top, 8)

                            // 버전
                            Text("소우주 v1.0.0")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.15))
                                .padding(.top, 8)
                                .padding(.bottom, 20)
                        }
                    }
                }

                // 커스텀 얼럿 — 로그아웃
                if store.showSignOutAlert {
                    CosmicAlertView(
                        title: "로그아웃",
                        message: "정말 로그아웃 하시겠어요?",
                        confirmTitle: "로그아웃",
                        isDestructive: false,
                        onConfirm: { store.send(.confirmSignOut) },
                        onCancel: { store.send(.dismissSignOutAlert) }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: store.showSignOutAlert)
                }

                // 커스텀 얼럿 — 계정 삭제
                if store.showDeleteAlert {
                    CosmicAlertView(
                        title: "계정을 삭제하시겠어요?",
                        message: "모든 기록이 사라지며\n되돌릴 수 없어요",
                        confirmTitle: "삭제",
                        isDestructive: true,
                        onConfirm: { store.send(.confirmDeleteAccount) },
                        onCancel: { store.send(.dismissDeleteAlert) }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: store.showDeleteAlert)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $store.showNicknameChange) {
                NicknameInputView(
                    store: store.scope(state: \.nicknameState, action: \.nickname)
                )
            }
        }
    }
}
