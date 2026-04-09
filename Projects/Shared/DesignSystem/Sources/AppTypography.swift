import SwiftUI

// MARK: - App Typography (디자인 토큰)

public enum AppTypography {

    /// 대형 타이틀 (온보딩, 메인 화면)
    public static let largeTitle = Font.system(size: 24, weight: .bold)

    /// 중형 타이틀 (섹션 헤더)
    public static let title = Font.system(size: 22, weight: .bold)

    /// 본문
    public static let body = Font.system(size: 14)

    /// 본문 (강조)
    public static let bodyMedium = Font.system(size: 14, weight: .medium)
}
