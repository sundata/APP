import Foundation

/// 日付まわりのユーティリティ。すべて「表示都市のローカル日付」を基準にする。
public enum KoyomiCalendar {
    /// 日本標準時のグレゴリオ暦。テストや fallback の既定値。
    public static var japan: Calendar {
        calendar(timeZoneIdentifier: "Asia/Tokyo")
    }

    public static func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 9 * 3600)!
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    /// `yyyy-MM-dd` 形式のローカル日付キー。永続化とシードの基礎になる。
    public static func dayKey(for date: Date, calendar: Calendar = japan) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 1, components.day ?? 1)
    }

    /// 1970-01-01 からの経過日数（ローカル日付基準）。
    /// 連続する日で必ず 1 ずつ増えるため、「7 日間で同じ内容を出さない」制約に使う。
    public static func dayNumber(for date: Date, calendar: Calendar = japan) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        let epoch = Date(timeIntervalSince1970: 0)
        let epochStart = calendar.startOfDay(for: epoch)
        return calendar.dateComponents([.day], from: epochStart, to: startOfDay).day ?? 0
    }

    public static func startOfDay(for date: Date, calendar: Calendar = japan) -> Date {
        calendar.startOfDay(for: date)
    }

    /// 同じローカル日かどうか。
    public static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = japan) -> Bool {
        dayKey(for: lhs, calendar: calendar) == dayKey(for: rhs, calendar: calendar)
    }

    /// 曜日の日本語表記。
    public static func weekdaySymbol(for date: Date, calendar: Calendar = japan) -> String {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        let weekday = calendar.component(.weekday, from: date)
        return symbols[max(0, min(6, weekday - 1))]
    }

    /// 表示用の日付文字列（例: 8月29日（土））。
    public static func displayDate(for date: Date, calendar: Calendar = japan) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        let weekday = weekdaySymbol(for: date, calendar: calendar)
        return "\(components.month ?? 1)月\(components.day ?? 1)日（\(weekday)）"
    }
}

/// 季節。天気が取得できないときの fallback 文脈として使う。
public enum Season: String, Codable, CaseIterable, Sendable {
    case spring, summer, autumn, winter

    public var japaneseName: String {
        switch self {
        case .spring: "春"
        case .summer: "夏"
        case .autumn: "秋"
        case .winter: "冬"
        }
    }

    public static func from(month: Int) -> Season {
        switch month {
        case 3, 4, 5: .spring
        case 6, 7, 8: .summer
        case 9, 10, 11: .autumn
        default: .winter
        }
    }

    public static func from(date: Date, calendar: Calendar = KoyomiCalendar.japan) -> Season {
        from(month: calendar.component(.month, from: date))
    }
}

/// 月相。信頼できるデータ源から取得できた場合のみ設定する（推測で埋めない）。
public enum MoonPhase: String, Codable, CaseIterable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous
    case fullMoon, waningGibbous, lastQuarter, waningCrescent

    public var japaneseName: String {
        switch self {
        case .newMoon: "新月"
        case .waxingCrescent: "三日月"
        case .firstQuarter: "上弦の月"
        case .waxingGibbous: "十三夜月"
        case .fullMoon: "満月"
        case .waningGibbous: "十六夜月"
        case .lastQuarter: "下弦の月"
        case .waningCrescent: "有明月"
        }
    }
}
