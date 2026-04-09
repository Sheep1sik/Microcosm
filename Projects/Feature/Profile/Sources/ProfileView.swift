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
        ZStack {
            AppColors.surfaceDark
                .ignoresSafeArea()

            StarfieldBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
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
                    }
                }

                // 버전 (하단 고정)
                Text("소우주 v1.0.0")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.bottom, 12)
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

// MARK: - Starfield Background

private struct StarfieldBackground: View {
    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private let stars: [Star] = {
        var rng = SplitMix64(seed: 42)
        return (0..<120).map { _ in
            Star(
                x: CGFloat.random(in: 0...1, using: &rng),
                y: CGFloat.random(in: 0...1, using: &rng),
                size: CGFloat.random(in: 0.5...2.0, using: &rng),
                opacity: Double.random(in: 0.1...0.6, using: &rng)
            )
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            for star in stars {
                let point = CGPoint(x: star.x * size.width, y: star.y * size.height)
                let rect = CGRect(
                    x: point.x - star.size / 2,
                    y: point.y - star.size / 2,
                    width: star.size,
                    height: star.size
                )
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity)))

                // 밝은 별에 작은 glow 추가
                if star.opacity > 0.35 {
                    let glowR = star.size * 3
                    let glowRect = CGRect(
                        x: point.x - glowR / 2,
                        y: point.y - glowR / 2,
                        width: glowR,
                        height: glowR
                    )
                    let grad = Gradient(colors: [
                        .white.opacity(star.opacity * 0.3),
                        .clear
                    ])
                    ctx.fill(
                        Path(ellipseIn: glowRect),
                        with: .radialGradient(grad, center: point, startRadius: 0, endRadius: glowR / 2)
                    )
                }
            }
        }
        .drawingGroup()
    }
}
