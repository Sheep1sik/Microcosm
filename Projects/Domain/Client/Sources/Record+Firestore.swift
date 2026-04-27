import Foundation
import DomainEntity

extension Record {
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
            // 초기 버전 스키마 호환
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
