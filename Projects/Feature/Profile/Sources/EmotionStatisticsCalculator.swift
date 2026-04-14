import Foundation
import DomainEntity

/// EmotionStatisticsView 의 값 계산 로직을 View 와 분리한 순수 계산기.
/// View 는 렌더링에만 집중하고, 수치/분포 계산은 이 타입에서 단위 테스트한다.
struct EmotionStatisticsCalculator {
    let records: [Record]
    let referenceDate: Date
    let calendar: Calendar

    init(
        records: [Record],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.records = records
        self.referenceDate = referenceDate
        self.calendar = calendar
    }

    // MARK: - Summary

    var totalCount: Int { records.count }

    var currentMonthCount: Int {
        records.filter {
            calendar.isDate($0.createdAt, equalTo: referenceDate, toGranularity: .month)
        }.count
    }

    /// 오늘(또는 어제)부터 거꾸로 이어지는 연속 기록 일수.
    /// - 오늘/어제에 기록이 없으면 0.
    /// - 하루라도 건너뛰면 거기서 끊긴다.
    var currentStreak: Int {
        let uniqueDays = Set(records.map {
            calendar.startOfDay(for: $0.createdAt)
        }).sorted(by: >)

        guard let latest = uniqueDays.first else { return 0 }

        let today = calendar.startOfDay(for: referenceDate)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        guard latest >= yesterday else { return 0 }

        var streak = 1
        for i in 1..<uniqueDays.count {
            guard let expected = calendar.date(byAdding: .day, value: -1, to: uniqueDays[i - 1]) else { break }
            if calendar.isDate(uniqueDays[i], inSameDayAs: expected) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Monthly

    struct MonthlyBucket: Equatable {
        let yearMonthKey: String
        let month: Int
        let count: Int
    }

    /// 기준 시점을 포함한 최근 6개월의 기록 수.
    /// 오래된 달 -> 최근 달 순.
    var recentMonthlyBuckets: [MonthlyBucket] {
        (0..<6).reversed().compactMap { offset -> MonthlyBucket? in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { return nil }
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let key = String(format: "%04d-%02d", year, month)
            let count = records.filter {
                let y = calendar.component(.year, from: $0.createdAt)
                let m = calendar.component(.month, from: $0.createdAt)
                return y == year && m == month
            }.count
            return MonthlyBucket(yearMonthKey: key, month: month, count: count)
        }
    }

    // MARK: - Tone Distribution

    /// 색상 톤 순서: 열정 / 따뜻함 / 평온 / 차분함 / 몽환.
    /// 채도가 낮으면 차분함(인덱스 3)로 몰아넣는다.
    enum Tone: Int, CaseIterable {
        case passion   // 0
        case warm      // 1
        case calm      // 2
        case serene    // 3
        case dreamy    // 4
    }

    static func classify(_ color: RecordColor) -> Tone {
        let h = hue(of: color)
        let sat = saturation(of: color)
        if sat < 0.12 { return .serene }
        if h < 30 || h >= 330 { return .passion }
        if h < 75 { return .warm }
        if h < 165 { return .calm }
        if h < 260 { return .serene }
        return .dreamy
    }

    /// 톤별 개수(0~totalCount). 순서는 Tone.allCases 와 동일.
    func toneCounts() -> [Int] {
        var counts = Array(repeating: 0, count: Tone.allCases.count)
        for record in records {
            let tone = Self.classify(record.resolvedProfile.primaryColor)
            counts[tone.rawValue] += 1
        }
        return counts
    }

    /// 톤별 비율(총합 1.0). 기록이 0개면 전부 0.
    func toneRatios() -> [Double] {
        let counts = toneCounts()
        let total = Double(counts.reduce(0, +))
        guard total > 0 else { return Array(repeating: 0, count: counts.count) }
        return counts.map { Double($0) / total }
    }

    // MARK: - Color Geometry (pure)

    static func hue(of color: RecordColor) -> Double {
        let r = color.r, g = color.g, b = color.b
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        guard delta > 0.001 else { return 0 }

        var h: Double
        if maxC == r {
            h = (g - b) / delta
            if h < 0 { h += 6 }
        } else if maxC == g {
            h = 2 + (b - r) / delta
        } else {
            h = 4 + (r - g) / delta
        }
        return h * 60
    }

    static func saturation(of color: RecordColor) -> Double {
        let maxC = max(color.r, color.g, color.b)
        let minC = min(color.r, color.g, color.b)
        guard maxC > 0.001 else { return 0 }
        return (maxC - minC) / maxC
    }
}
