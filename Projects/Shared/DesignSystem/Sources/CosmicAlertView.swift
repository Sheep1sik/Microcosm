import SwiftUI

public struct CosmicAlertView: View {
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(
        title: String,
        message: String,
        confirmTitle: String,
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            // 배경 오버레이
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // 알럿 카드
            VStack(spacing: 0) {
                // 타이틀
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                // 메시지
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                Divider()
                    .background(Color.white.opacity(0.08))

                // 버튼 영역
                HStack(spacing: 0) {
                    // 취소 버튼
                    Button {
                        onCancel()
                    } label: {
                        Text("취소")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }

                    Divider()
                        .frame(height: 44)
                        .background(Color.white.opacity(0.08))

                    // 확인 버튼
                    Button {
                        onConfirm()
                    } label: {
                        Text(confirmTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isDestructive ? .red.opacity(0.9) : AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
            .padding(.horizontal, 48)
        }
    }
}
