import SwiftUI
import Charts
import DomainEntity
import SharedDesignSystem

// MARK: - Emotion Statistics View

struct EmotionStatisticsView: View {
    let records: [Record]

    var body: some View {
        VStack(spacing: 20) {
            // 기록 요약
            recordSummarySection

            // 감정 색상 스펙트럼
            colorSpectrumSection

            // 월별 기록 추이
            monthlyTrendSection

            // 색상 톤 분포
            colorToneSection
        }
    }

    // MARK: - Record Summary

    private var recordSummarySection: some View {
        HStack(spacing: 0) {
            summaryItem(value: "\(records.count)", label: "총 기록")
            summaryItem(value: "\(currentMonthCount)", label: "이번 달")
            summaryItem(value: "\(currentStreak)일", label: "연속 기록")
        }
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var currentMonthCount: Int {
        let cal = Calendar.current
        let now = Date()
        return records.filter {
            cal.isDate($0.createdAt, equalTo: now, toGranularity: .month)
        }.count
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        let uniqueDays = Set(records.map {
            cal.startOfDay(for: $0.createdAt)
        }).sorted(by: >)

        guard let latest = uniqueDays.first else { return 0 }

        // 오늘 또는 어제부터 시작해야 streak 유효
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        guard latest >= yesterday else { return 0 }

        var streak = 1
        for i in 1..<uniqueDays.count {
            let expected = cal.date(byAdding: .day, value: -1, to: uniqueDays[i - 1])!
            if cal.isDate(uniqueDays[i], inSameDayAs: expected) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Color Spectrum

    private var colorSpectrumSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("감정 색상 스펙트럼")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            if records.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.02))
                    .frame(height: 32)
                    .overlay {
                        Text("기록을 남기면 색상이 채워져요")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textTertiary)
                    }
            } else {
                let sorted = records.sorted {
                    hue(of: $0.resolvedProfile.primaryColor) < hue(of: $1.resolvedProfile.primaryColor)
                }

                HStack(spacing: 1.5) {
                    ForEach(Array(sorted.prefix(60).enumerated()), id: \.offset) { _, record in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(record.resolvedProfile.primaryColor.swiftUIColor)
                            .frame(height: 32)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func hue(of color: RecordColor) -> Double {
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

    // MARK: - Monthly Trend

    private var monthlyTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("월별 기록 추이")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            Chart(monthlyData, id: \.month) { item in
                BarMark(
                    x: .value("월", item.label),
                    y: .value("기록", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accent.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...(max(maxMonthlyCount, 5)))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .frame(height: 140)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private struct MonthlyItem {
        let month: String
        let label: String
        let count: Int
    }

    private var maxMonthlyCount: Int {
        monthlyData.map(\.count).max() ?? 0
    }

    private var monthlyData: [MonthlyItem] {
        let cal = Calendar.current
        let now = Date()

        // 최근 6개월
        return (0..<6).reversed().compactMap { offset -> MonthlyItem? in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let year = cal.component(.year, from: date)
            let month = cal.component(.month, from: date)
            let key = String(format: "%04d-%02d", year, month)

            let count = records.filter {
                let y = cal.component(.year, from: $0.createdAt)
                let m = cal.component(.month, from: $0.createdAt)
                return y == year && m == month
            }.count

            return MonthlyItem(month: key, label: "\(month)월", count: count)
        }
    }

    // MARK: - Color Tone Distribution

    private var colorToneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("색상 톤 분포")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                ForEach(toneDistribution, id: \.tone) { item in
                    VStack(spacing: 5) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: item.ratio)
                                .stroke(item.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(item.ratio * 100))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 42, height: 42)

                        Text(item.tone)
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private struct ToneItem {
        let tone: String
        let ratio: Double
        let color: Color
    }

    private var toneDistribution: [ToneItem] {
        let empty: [ToneItem] = [
            ToneItem(tone: "열정", ratio: 0, color: Color(red: 1.0, green: 0.45, blue: 0.35)),
            ToneItem(tone: "따뜻함", ratio: 0, color: Color(red: 1.0, green: 0.75, blue: 0.4)),
            ToneItem(tone: "평온", ratio: 0, color: Color(red: 0.4, green: 0.85, blue: 0.55)),
            ToneItem(tone: "차분함", ratio: 0, color: Color(red: 0.4, green: 0.7, blue: 1.0)),
            ToneItem(tone: "몽환", ratio: 0, color: Color(red: 0.7, green: 0.5, blue: 0.95)),
        ]
        guard !records.isEmpty else { return empty }

        // 색상환 5분할: 열정(빨강/핑크), 따뜻함(주황/노랑), 평온(초록), 차분함(파랑/시안), 몽환(보라)
        var counts = [0, 0, 0, 0, 0]

        for record in records {
            let c = record.resolvedProfile.primaryColor
            let h = hue(of: c)
            let sat = saturation(of: c)

            if sat < 0.12 {
                // 저채도는 가장 가까운 톤에 분배
                counts[3] += 1
            } else if h < 30 || h >= 330 {
                counts[0] += 1 // 열정 (빨강/핑크)
            } else if h < 75 {
                counts[1] += 1 // 따뜻함 (주황/노랑)
            } else if h < 165 {
                counts[2] += 1 // 평온 (초록)
            } else if h < 260 {
                counts[3] += 1 // 차분함 (파랑/시안)
            } else {
                counts[4] += 1 // 몽환 (보라)
            }
        }

        let total = Double(counts.reduce(0, +))
        return zip(empty, counts).map { item, count in
            ToneItem(tone: item.tone, ratio: Double(count) / total, color: item.color)
        }
    }

    private func saturation(of color: RecordColor) -> Double {
        let maxC = max(color.r, color.g, color.b)
        let minC = min(color.r, color.g, color.b)
        guard maxC > 0.001 else { return 0 }
        return (maxC - minC) / maxC
    }
}
