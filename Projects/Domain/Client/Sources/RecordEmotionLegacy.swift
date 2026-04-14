import Foundation
import DomainEntity

/// Firestore 에 남아 있던 초기 버전의 "감정" 데이터(정리되기 전 `emotion` 필드) 를
/// 현재 스키마인 `RecordColor` 로 매핑하기 위한 레거시 타입. 신규 기록은 이 경로를 타지 않는다.
public enum Emotion: String, Codable, CaseIterable {
    case calm
    case excited
    case sad
    case joyful
    case angry
    case grateful
    case anxious
    case love
    case neutral

    public var label: String {
        switch self {
        case .calm: "평온"
        case .excited: "설렘"
        case .sad: "슬픔"
        case .joyful: "기쁨"
        case .angry: "화남"
        case .grateful: "감사"
        case .anxious: "불안"
        case .love: "사랑"
        case .neutral: "중립"
        }
    }

    public func toRecordColor() -> RecordColor {
        switch self {
        case .calm:     RecordColor(r: 0.55, g: 0.83, b: 0.97)
        case .excited:  RecordColor(r: 0.73, g: 0.55, b: 0.99)
        case .sad:      RecordColor(r: 0.40, g: 0.52, b: 0.90)
        case .joyful:   RecordColor(r: 1.00, g: 0.84, b: 0.30)
        case .angry:    RecordColor(r: 0.95, g: 0.35, b: 0.35)
        case .grateful: RecordColor(r: 1.00, g: 0.65, b: 0.30)
        case .anxious:  RecordColor(r: 0.35, g: 0.30, b: 0.70)
        case .love:     RecordColor(r: 0.95, g: 0.40, b: 0.65)
        case .neutral:  RecordColor(r: 0.65, g: 0.65, b: 0.70)
        }
    }
}
