import Foundation

public enum FormatHelper {
    public static func parseYearMonth(_ ym: String) -> (year: Int, month: Int) {
        let parts = ym.split(separator: "-")
        guard parts.count >= 2 else { return (2026, 1) }
        return (Int(parts[0]) ?? 2026, Int(parts[1]) ?? 1)
    }

    public static func yearMonthLabel(_ ym: String) -> String {
        let (year, month) = parseYearMonth(ym)
        return "\(year)년 \(month)월"
    }

    private static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "M/d HH:mm"
        return df
    }()

    public static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }
}
