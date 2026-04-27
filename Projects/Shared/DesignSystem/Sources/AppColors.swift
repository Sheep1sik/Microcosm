import SwiftUI
import UIKit

// MARK: - App Colors (디자인 토큰)

public enum AppColors {

    // MARK: - Background

    /// 앱 전체 기본 배경색 (진한 네이비)
    public static let background = Color(red: 0.012, green: 0.024, blue: 0.031)

    /// SpriteKit Scene 배경색
    public static let sceneBackground = UIColor(red: 0.012, green: 0.024, blue: 0.031, alpha: 1)

    /// 패널/오버레이 배경색
    public static let surfaceDark = Color(red: 0.01, green: 0.02, blue: 0.04)

    /// 카드/입력 필드 배경색
    public static let surfaceElevated = Color(red: 0.04, green: 0.06, blue: 0.09)

    /// 카드/입력 필드 배경색 (UIColor, SpriteKit용)
    public static let surfaceElevatedUI = UIColor(red: 0.04, green: 0.06, blue: 0.09, alpha: 0.95)

    /// 탭바 배경색
    public static let tabBarBackground = UIColor(red: 0.01, green: 0.02, blue: 0.04, alpha: 0.9)

    // MARK: - Accent

    /// 주요 강조색 (라이트 블루)
    public static let accent = Color(red: 0.55, green: 0.83, blue: 0.97)

    /// 성공/완료 표시 (그린)
    public static let success = Color(red: 0.3, green: 0.85, blue: 0.5)

    /// 기본 폴백 색상 (라벤더)
    public static let fallback = Color(red: 0.6, green: 0.7, blue: 0.9)

    // MARK: - Text (white opacity 계열)

    /// 주요 텍스트
    public static let textPrimary = Color.white.opacity(0.8)

    /// 보조 텍스트
    public static let textSecondary = Color.white.opacity(0.6)

    /// 약한 텍스트 / 캡션
    public static let textTertiary = Color.white.opacity(0.4)

    /// 비활성 텍스트 / 플레이스홀더
    public static let textQuaternary = Color.white.opacity(0.3)

    // MARK: - Border & Divider

    /// 기본 보더
    public static let border = Color.white.opacity(0.08)

    /// 약한 보더
    public static let borderSubtle = Color.white.opacity(0.06)

    /// 강한 보더
    public static let borderStrong = Color.white.opacity(0.1)

    // MARK: - Overlay

    /// 반투명 오버레이
    public static let overlay = Color.black.opacity(0.5)

    /// 진한 오버레이
    public static let overlayHeavy = Color.black.opacity(0.8)
}

// MARK: - SpriteKit Dust Star Colors

public enum DustStarColors {
    public static let palette: [UIColor] = [
        .white,
        UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 1),
        UIColor(red: 0.9, green: 0.92, blue: 1.0, alpha: 1),
        UIColor(red: 1.0, green: 0.95, blue: 0.8, alpha: 1),
        UIColor(red: 1.0, green: 0.85, blue: 0.6, alpha: 1),
        UIColor(red: 0.85, green: 0.88, blue: 1.0, alpha: 1),
    ]
}
