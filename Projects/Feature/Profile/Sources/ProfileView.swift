import SwiftUI
import ComposableArchitecture
import DomainClient
import DomainEntity
import FeatureNickname

public struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    public init(store: StoreOf<ProfileFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.02, blue: 0.04)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 닉네임 + 이름
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text(String((store.userProfile.nickname ?? "우").prefix(1)))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                        Text(store.userProfile.nickname ?? store.displayName ?? "우주인")
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(.white)
                        if !store.userProfile.email.isEmpty {
                            Text(store.userProfile.email)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 40)

                    // 메뉴
                    VStack(spacing: 0) {
                        menuRow(icon: "pencil", title: "닉네임 변경") {
                            store.send(.changeNicknameTapped)
                        }
                        Divider().background(Color.white.opacity(0.08))
                        menuRow(icon: "rectangle.portrait.and.arrow.right", title: "로그아웃") {
                            store.send(.signOutTapped)
                        }
                        Divider().background(Color.white.opacity(0.08))
                        menuRow(icon: "trash", title: "계정 삭제", isDestructive: true) {
                            store.send(.deleteAccountTapped)
                        }
                    }
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)

                    // 개발용
                    #if DEBUG
                    VStack(spacing: 0) {
                        menuRow(icon: "arrow.counterclockwise", title: "온보딩 리셋 (DEV)") {
                            store.send(.resetOnboardingTapped)
                        }
                    }
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    #endif

                    // 버전
                    Text("소우주 v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.2))
                        .padding(.top, 20)

                    Spacer()
                }
            }
        }
        .alert("계정을 삭제하시겠어요?", isPresented: $store.showDeleteAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) { store.send(.confirmDeleteAccount) }
        } message: {
            Text("모든 기록이 사라지며 되돌릴 수 없어요")
        }
        .sheet(isPresented: $store.showNicknameChange) {
            NicknameInputView(
                store: store.scope(state: \.nicknameState, action: \.nickname)
            )
        }
    }

    private func menuRow(icon: String, title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(isDestructive ? .red.opacity(0.8) : .white.opacity(0.6))
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isDestructive ? .red.opacity(0.8) : .white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
