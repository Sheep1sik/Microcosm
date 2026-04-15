import SwiftUI
import Charts
import DomainEntity
import SharedDesignSystem
import SharedRecordVisuals

// MARK: - Emotion Statistics View

struct EmotionStatisticsView: View {
    let records: [Record]

    private var calculator: EmotionStatisticsCalculator {
        EmotionStatisticsCalculator(records: records)
    }

    var body: some View {
        VStack(spacing: 20) {
            recordSummarySection
            colorSpectrumSection
            monthlyTrendSection
            colorToneSection
        }
    }

    // MARK: - Record Summary

    private var recordSummarySection: some View {
        HStack(spacing: 0) {
            summaryItem(value: "\(calculator.totalCount)", label: "총 기록")
            summaryItem(value: "\(calculator.currentMonthCount)", label: "이번 달")
            summaryItem(value: "\(calculator.currentStreak)일", label: "연속 기록")
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
                    EmotionStatisticsCalculator.hue(of: $0.resolvedProfile.primaryColor)
                        < EmotionStatisticsCalculator.hue(of: $1.resolvedProfile.primaryColor)
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

    // MARK: - Monthly Trend

    private var monthlyTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("월별 기록 추이")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            Chart(monthlyData, id: \.yearMonthKey) { item in
                BarMark(
                    x: .value("월", "\(item.month)월"),
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
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
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

    private var monthlyData: [EmotionStatisticsCalculator.MonthlyBucket] {
        calculator.recentMonthlyBuckets
    }

    private var maxMonthlyCount: Int {
        monthlyData.map(\.count).max() ?? 0
    }

    // MARK: - Color Tone Distribution

    private var colorToneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("색상 톤 분포")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                ForEach(Array(toneViewItems.enumerated()), id: \.offset) { _, item in
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

                        Text(item.label)
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

    private struct ToneViewItem {
        let label: String
        let ratio: Double
        let color: Color
    }

    private var toneViewItems: [ToneViewItem] {
        let ratios = calculator.toneRatios()
        let labels = ["열정", "따뜻함", "평온", "차분함", "몽환"]
        let colors: [Color] = [
            Color(red: 1.0, green: 0.45, blue: 0.35),
            Color(red: 1.0, green: 0.75, blue: 0.4),
            Color(red: 0.4, green: 0.85, blue: 0.55),
            Color(red: 0.4, green: 0.7, blue: 1.0),
            Color(red: 0.7, green: 0.5, blue: 0.95),
        ]
        return zip(labels, zip(ratios, colors)).map { label, pair in
            ToneViewItem(label: label, ratio: pair.0, color: pair.1)
        }
    }
}
