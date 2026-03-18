import Foundation
import CoreGraphics

public struct RecordColor: Equatable, Hashable, Codable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double = 0.6, g: Double = 0.7, b: Double = 0.9) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let fallback = RecordColor(r: 0.6, g: 0.7, b: 0.9)

    public func clamped() -> RecordColor {
        RecordColor(
            r: max(0, min(1, r)),
            g: max(0, min(1, g)),
            b: max(0, min(1, b))
        )
    }
}

// MARK: - Star Visual Profile

public struct StarVisualProfile: Equatable, Hashable, Codable {
    public var primaryColor: RecordColor
    public var secondaryColor: RecordColor
    public var glowColor: RecordColor
    public var size: Double
    public var brightness: Double
    public var twinkleSpeed: Double
    public var twinkleIntensity: Double
    public var motionAmplitude: Double
    public var motionSpeed: Double

    public init(
        primaryColor: RecordColor,
        secondaryColor: RecordColor,
        glowColor: RecordColor,
        size: Double = 0.5,
        brightness: Double = 0.5,
        twinkleSpeed: Double = 0.5,
        twinkleIntensity: Double = 0.5,
        motionAmplitude: Double = 0.5,
        motionSpeed: Double = 0.5
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.glowColor = glowColor
        self.size = max(0, min(1, size))
        self.brightness = max(0, min(1, brightness))
        self.twinkleSpeed = max(0, min(1, twinkleSpeed))
        self.twinkleIntensity = max(0, min(1, twinkleIntensity))
        self.motionAmplitude = max(0, min(1, motionAmplitude))
        self.motionSpeed = max(0, min(1, motionSpeed))
    }

    public static let fallback = StarVisualProfile(
        primaryColor: .fallback,
        secondaryColor: RecordColor(r: 0.5, g: 0.6, b: 0.8),
        glowColor: RecordColor(r: 0.4, g: 0.5, b: 0.7),
        size: 0.5, brightness: 0.5,
        twinkleSpeed: 0.5, twinkleIntensity: 0.5,
        motionAmplitude: 0.5, motionSpeed: 0.5
    )

    /// 레거시 RecordColor → 결정론적 StarVisualProfile 파생
    public static func from(legacyColor c: RecordColor) -> StarVisualProfile {
        let seed = c.r * 7.3 + c.g * 13.7 + c.b * 23.1
        func hash(_ v: Double) -> Double {
            let x = sin(v * 127.1 + seed * 311.7) * 43758.5453
            return x - x.rounded(.down)
        }
        return StarVisualProfile(
            primaryColor: c,
            secondaryColor: RecordColor(
                r: max(0, min(1, c.r * 0.8 + hash(1.0) * 0.2)),
                g: max(0, min(1, c.g * 0.8 + hash(2.0) * 0.2)),
                b: max(0, min(1, c.b * 0.8 + hash(3.0) * 0.2))
            ),
            glowColor: RecordColor(
                r: max(0, min(1, c.r * 0.6 + hash(4.0) * 0.3)),
                g: max(0, min(1, c.g * 0.6 + hash(5.0) * 0.3)),
                b: max(0, min(1, c.b * 0.6 + hash(6.0) * 0.3))
            ),
            size: 0.3 + hash(7.0) * 0.4,
            brightness: 0.4 + hash(8.0) * 0.4,
            twinkleSpeed: 0.3 + hash(9.0) * 0.4,
            twinkleIntensity: 0.2 + hash(10.0) * 0.4,
            motionAmplitude: 0.2 + hash(11.0) * 0.4,
            motionSpeed: 0.3 + hash(12.0) * 0.4
        )
    }
}

// MARK: - Star Position

public struct StarPosition: Equatable, Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

public struct Record: Identifiable, Equatable, Hashable {
    public let id: String
    public var content: String
    public var createdAt: Date
    public var color: RecordColor
    public var visualProfile: StarVisualProfile?
    public var starName: String
    public var isOnboardingRecord: Bool
    public var starPosition: StarPosition?

    public var resolvedProfile: StarVisualProfile {
        visualProfile ?? StarVisualProfile.from(legacyColor: color)
    }

    public init(
        id: String = UUID().uuidString,
        content: String,
        color: RecordColor = .fallback,
        visualProfile: StarVisualProfile? = nil,
        starName: String = "",
        createdAt: Date = .now,
        isOnboardingRecord: Bool = false,
        starPosition: StarPosition? = nil
    ) {
        self.id = id
        self.content = content
        self.color = color
        self.visualProfile = visualProfile
        self.starName = starName
        self.createdAt = createdAt
        self.isOnboardingRecord = isOnboardingRecord
        self.starPosition = starPosition
    }

    // MARK: - Firestore Serialization

    public func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "content": content,
            "createdAt": createdAt,
            "color": ["r": color.r, "g": color.g, "b": color.b],
            "starName": starName,
            "isOnboardingRecord": isOnboardingRecord,
        ]
        if let vp = visualProfile {
            data["visualProfile"] = [
                "pc": ["r": vp.primaryColor.r, "g": vp.primaryColor.g, "b": vp.primaryColor.b],
                "sc": ["r": vp.secondaryColor.r, "g": vp.secondaryColor.g, "b": vp.secondaryColor.b],
                "gc": ["r": vp.glowColor.r, "g": vp.glowColor.g, "b": vp.glowColor.b],
                "sz": vp.size, "br": vp.brightness,
                "ts": vp.twinkleSpeed, "ti": vp.twinkleIntensity,
                "ma": vp.motionAmplitude, "ms": vp.motionSpeed,
            ]
        }
        if let sp = starPosition {
            data["starPosition"] = ["x": sp.x, "y": sp.y]
        }
        return data
    }

    public static func fromFirestoreData(_ data: [String: Any], id: String) -> Record? {
        guard let content = data["content"] as? String else { return nil }

        let color: RecordColor
        if let colorData = data["color"] as? [String: Any],
           let r = colorData["r"] as? Double,
           let g = colorData["g"] as? Double,
           let b = colorData["b"] as? Double {
            color = RecordColor(r: r, g: g, b: b)
        } else if let emotionRaw = data["emotion"] as? String,
                  let emotion = Emotion(rawValue: emotionRaw) {
            // 기존 emotion 기반 데이터 마이그레이션
            color = emotion.toRecordColor()
        } else {
            color = .fallback
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Date {
            createdAt = timestamp
        } else {
            createdAt = .now
        }

        let starName = data["starName"] as? String ?? ""
        let isOnboardingRecord = data["isOnboardingRecord"] as? Bool ?? false

        var visualProfile: StarVisualProfile? = nil
        if let vpData = data["visualProfile"] as? [String: Any],
           let pc = vpData["pc"] as? [String: Any],
           let sc = vpData["sc"] as? [String: Any],
           let gc = vpData["gc"] as? [String: Any] {
            let pcColor = RecordColor(
                r: pc["r"] as? Double ?? 0.6,
                g: pc["g"] as? Double ?? 0.7,
                b: pc["b"] as? Double ?? 0.9
            )
            let scColor = RecordColor(
                r: sc["r"] as? Double ?? 0.5,
                g: sc["g"] as? Double ?? 0.6,
                b: sc["b"] as? Double ?? 0.8
            )
            let gcColor = RecordColor(
                r: gc["r"] as? Double ?? 0.4,
                g: gc["g"] as? Double ?? 0.5,
                b: gc["b"] as? Double ?? 0.7
            )
            visualProfile = StarVisualProfile(
                primaryColor: pcColor,
                secondaryColor: scColor,
                glowColor: gcColor,
                size: vpData["sz"] as? Double ?? 0.5,
                brightness: vpData["br"] as? Double ?? 0.5,
                twinkleSpeed: vpData["ts"] as? Double ?? 0.5,
                twinkleIntensity: vpData["ti"] as? Double ?? 0.5,
                motionAmplitude: vpData["ma"] as? Double ?? 0.5,
                motionSpeed: vpData["ms"] as? Double ?? 0.5
            )
        }

        var starPosition: StarPosition? = nil
        if let spData = data["starPosition"] as? [String: Any],
           let spX = spData["x"] as? Double,
           let spY = spData["y"] as? Double {
            starPosition = StarPosition(x: spX, y: spY)
        }

        return Record(
            id: id,
            content: content,
            color: color,
            visualProfile: visualProfile,
            starName: starName,
            createdAt: createdAt,
            isOnboardingRecord: isOnboardingRecord,
            starPosition: starPosition
        )
    }
}

// MARK: - Legacy Emotion (마이그레이션 용도)

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
