import XCTest
@testable import FeatureProfile
import DomainEntity

@MainActor
final class EmotionStatisticsCalculatorTests: XCTestCase {

    // MARK: - Helpers

    private let cal = Calendar(identifier: .gregorian)

    /// 기준일 고정: 2026-04-15
    private let ref: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 15
        return Calendar(identifier: .gregorian).date(from: comps)!
    }()

    private func record(daysBefore: Int = 0, color: RecordColor = RecordColor(r: 1, g: 0, b: 0)) -> Record {
        let cal = Calendar(identifier: .gregorian)
        let date = cal.date(byAdding: .day, value: -daysBefore, to: ref)!
        return Record(content: "t", color: color, createdAt: date)
    }

    // MARK: - totalCount / currentMonthCount

    func test_totalCount_그대로반영() {
        let calc = EmotionStatisticsCalculator(
            records: [record(), record(), record()],
            referenceDate: ref,
            calendar: cal
        )
        XCTAssertEqual(calc.totalCount, 3)
    }

    func test_currentMonthCount_같은달만카운트() {
        // 기준: 2026-04-15. 4월 안쪽 2개, 3월 1개, 5월 1개(미래)
        let april = record(daysBefore: 0)
        let aprilEarly = record(daysBefore: 14) // 2026-04-01
        let march = record(daysBefore: 20)      // 2026-03-26

        let calc = EmotionStatisticsCalculator(
            records: [april, aprilEarly, march],
            referenceDate: ref,
            calendar: cal
        )
        XCTAssertEqual(calc.currentMonthCount, 2)
    }

    // MARK: - currentStreak

    func test_currentStreak_오늘부터3일연속() {
        let calc = EmotionStatisticsCalculator(
            records: [record(daysBefore: 0), record(daysBefore: 1), record(daysBefore: 2)],
            referenceDate: ref,
            calendar: cal
        )
        XCTAssertEqual(calc.currentStreak, 3)
    }

    func test_currentStreak_어제부터_시작도_유효() {
        let calc = EmotionStatisticsCalculator(
            records: [record(daysBefore: 1), record(daysBefore: 2)],
            referenceDate: ref,
            calendar: cal
        )
        XCTAssertEqual(calc.currentStreak, 2)
    }

    func test_currentStreak_이틀전부터시작이면_0() {
        // 오늘/어제 없음 -> streak 끊김
        let calc = EmotionStatisticsCalculator(
            records: [record(daysBefore: 2), record(daysBefore: 3)],
            referenceDate: ref,
            calendar: cal
        )
        XCTAssertEqual(calc.currentStreak, 0)
    }

    func test_currentStreak_같은날여러개는_1일로() {
        let calc = EmotionStatisticsCalculator(
            records: [record(daysBefore: 0), record(daysBefore: 0), record(daysBefore: 0)],
            referenceDate: ref,
            calendar: cal
        )
        XCTAssertEqual(calc.currentStreak, 1)
    }

    func test_currentStreak_중간공백있으면_끊김() {
        // 오늘, 2일전 -> 어제가 비어 있으므로 1
        let calc = EmotionStatisticsCalculator(
            records: [record(daysBefore: 0), record(daysBefore: 2)],
            referenceDate: ref,
            calendar: cal
        )
        XCTAssertEqual(calc.currentStreak, 1)
    }

    func test_currentStreak_빈기록이면_0() {
        let calc = EmotionStatisticsCalculator(records: [], referenceDate: ref, calendar: cal)
        XCTAssertEqual(calc.currentStreak, 0)
    }

    // MARK: - recentMonthlyBuckets

    func test_recentMonthlyBuckets_최근6개월_오래된순() {
        // 4월 2개, 3월 1개, 1월 1개
        let april = record(daysBefore: 0)       // 2026-04
        let aprilEarly = record(daysBefore: 14) // 2026-04
        let march = record(daysBefore: 20)      // 2026-03
        let january = record(daysBefore: 90)    // ~2026-01

        let calc = EmotionStatisticsCalculator(
            records: [april, aprilEarly, march, january],
            referenceDate: ref,
            calendar: cal
        )
        let buckets = calc.recentMonthlyBuckets
        XCTAssertEqual(buckets.count, 6)
        // 마지막 달이 4월(기준달)이어야 함
        XCTAssertEqual(buckets.last?.month, 4)
        XCTAssertEqual(buckets.last?.count, 2)
        // 바로 직전이 3월
        XCTAssertEqual(buckets[buckets.count - 2].month, 3)
        XCTAssertEqual(buckets[buckets.count - 2].count, 1)
    }

    // MARK: - hue / saturation (pure)

    func test_hue_순수빨강_0도() {
        XCTAssertEqual(EmotionStatisticsCalculator.hue(of: RecordColor(r: 1, g: 0, b: 0)), 0, accuracy: 0.001)
    }

    func test_hue_순수초록_120도() {
        XCTAssertEqual(EmotionStatisticsCalculator.hue(of: RecordColor(r: 0, g: 1, b: 0)), 120, accuracy: 0.001)
    }

    func test_hue_순수파랑_240도() {
        XCTAssertEqual(EmotionStatisticsCalculator.hue(of: RecordColor(r: 0, g: 0, b: 1)), 240, accuracy: 0.001)
    }

    func test_hue_무채색_0_fallback() {
        XCTAssertEqual(EmotionStatisticsCalculator.hue(of: RecordColor(r: 0.5, g: 0.5, b: 0.5)), 0)
    }

    func test_saturation_순수색_1() {
        XCTAssertEqual(EmotionStatisticsCalculator.saturation(of: RecordColor(r: 1, g: 0, b: 0)), 1, accuracy: 0.001)
    }

    func test_saturation_무채색_0() {
        XCTAssertEqual(EmotionStatisticsCalculator.saturation(of: RecordColor(r: 0.5, g: 0.5, b: 0.5)), 0)
    }

    // MARK: - Tone classification

    func test_classify_빨강_열정() {
        XCTAssertEqual(EmotionStatisticsCalculator.classify(RecordColor(r: 1, g: 0, b: 0)), .passion)
    }

    func test_classify_주황_따뜻함() {
        // hue 약 30~75 범위
        XCTAssertEqual(EmotionStatisticsCalculator.classify(RecordColor(r: 1, g: 0.6, b: 0)), .warm)
    }

    func test_classify_초록_평온() {
        XCTAssertEqual(EmotionStatisticsCalculator.classify(RecordColor(r: 0, g: 1, b: 0)), .calm)
    }

    func test_classify_파랑_차분함() {
        XCTAssertEqual(EmotionStatisticsCalculator.classify(RecordColor(r: 0, g: 0, b: 1)), .serene)
    }

    func test_classify_보라_몽환() {
        // hue 약 270~290
        XCTAssertEqual(EmotionStatisticsCalculator.classify(RecordColor(r: 0.5, g: 0, b: 1)), .dreamy)
    }

    func test_classify_저채도는_차분함으로_몰림() {
        XCTAssertEqual(EmotionStatisticsCalculator.classify(RecordColor(r: 0.5, g: 0.5, b: 0.5)), .serene)
    }

    // MARK: - toneCounts / toneRatios

    func test_toneCounts_각분류에누적() {
        let red = record(color: RecordColor(r: 1, g: 0, b: 0))    // passion
        let orange = record(color: RecordColor(r: 1, g: 0.6, b: 0)) // warm
        let blue = record(color: RecordColor(r: 0, g: 0, b: 1))   // serene

        let calc = EmotionStatisticsCalculator(
            records: [red, red, orange, blue],
            referenceDate: ref,
            calendar: cal
        )
        XCTAssertEqual(calc.toneCounts(), [2, 1, 0, 1, 0])
    }

    func test_toneRatios_총합_1() {
        let red = record(color: RecordColor(r: 1, g: 0, b: 0))
        let blue = record(color: RecordColor(r: 0, g: 0, b: 1))

        let calc = EmotionStatisticsCalculator(
            records: [red, blue, blue, blue],
            referenceDate: ref,
            calendar: cal
        )
        let ratios = calc.toneRatios()
        XCTAssertEqual(ratios.reduce(0, +), 1.0, accuracy: 0.001)
        XCTAssertEqual(ratios[0], 0.25, accuracy: 0.001) // passion
        XCTAssertEqual(ratios[3], 0.75, accuracy: 0.001) // serene
    }

    func test_toneRatios_빈기록이면_전부0() {
        let calc = EmotionStatisticsCalculator(records: [], referenceDate: ref, calendar: cal)
        XCTAssertEqual(calc.toneRatios(), [0, 0, 0, 0, 0])
    }
}
