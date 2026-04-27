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
