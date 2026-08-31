import Foundation

/// 日付まわりのユーティリティ。シフト表は常に日本のローカル日付（Asia/Tokyo）を基準にする。
public enum KoyomiCalendar {
    /// 日本標準時のグレゴリオ暦。アプリ全体で唯一の暦。
    public static var japan: Calendar {
        calendar(timeZoneIdentifier: "Asia/Tokyo")
    }

    public static func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 9 * 3600)!
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 1 // 日曜はじまり
        return calendar
    }

    /// `yyyy-MM-dd` 形式のローカル日付キー。永続化の主キーになる唯一の生成関数。
    public static func dayKey(for date: Date, calendar: Calendar = japan) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return dayKey(year: components.year ?? 0, month: components.month ?? 1, day: components.day ?? 1)
    }

    public static func dayKey(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// `yyyy-MM-dd` から年月日を取り出す。書式が不正なら nil。
    public static func components(fromDayKey dayKey: String) -> (year: Int, month: Int, day: Int)? {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        return (year, month, day)
    }

    /// `yyyy-MM-dd` をその日の 0 時に戻す。存在しない日付（2 月 30 日など）は nil。
    public static func date(fromDayKey dayKey: String, calendar: Calendar = japan) -> Date? {
        guard let parsed = components(fromDayKey: dayKey) else { return nil }
        var components = DateComponents()
        components.year = parsed.year
        components.month = parsed.month
        components.day = parsed.day
        guard let date = calendar.date(from: components) else { return nil }
        // 2 月 30 日のような入力が別の日に丸められていないか確認する。
        guard self.dayKey(for: date, calendar: calendar) == dayKey else { return nil }
        return date
    }

    public static func startOfDay(for date: Date, calendar: Calendar = japan) -> Date {
        calendar.startOfDay(for: date)
    }

    /// 同じローカル日かどうか。
    public static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = japan) -> Bool {
        dayKey(for: lhs, calendar: calendar) == dayKey(for: rhs, calendar: calendar)
    }

    /// 1970-01-01 からの経過日数（ローカル日付基準）。日付範囲の日数計算に使う。
    public static func dayNumber(for date: Date, calendar: Calendar = japan) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        let epochStart = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.dateComponents([.day], from: epochStart, to: startOfDay).day ?? 0
    }

    /// 曜日（1 = 日曜 ... 7 = 土曜）。
    public static func weekday(for date: Date, calendar: Calendar = japan) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// 曜日の日本語 1 文字表記。
    public static func weekdaySymbol(for date: Date, calendar: Calendar = japan) -> String {
        weekdaySymbol(weekday: weekday(for: date, calendar: calendar))
    }

    public static func weekdaySymbol(weekday: Int) -> String {
        let symbols = ["日", "月", "火", "水", "木", "金", "土"]
        return symbols[max(0, min(6, weekday - 1))]
    }

    /// 表示用の日付文字列（例: 8月29日（土））。
    public static func displayDate(for date: Date, calendar: Calendar = japan) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        let weekday = weekdaySymbol(for: date, calendar: calendar)
        return "\(components.month ?? 1)月\(components.day ?? 1)日（\(weekday)）"
    }

    /// 日付キーの範囲（開始・終了は順不同でよい）。
    public static func dayKeys(from start: Date, to end: Date, calendar: Calendar = japan) -> [String] {
        let lower = min(calendar.startOfDay(for: start), calendar.startOfDay(for: end))
        let upper = max(calendar.startOfDay(for: start), calendar.startOfDay(for: end))
        var keys: [String] = []
        var cursor = lower
        while cursor <= upper {
            keys.append(dayKey(for: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return keys
    }

    /// 分（0 時からの経過分）を `HH:mm` に整形する。24 時以降は翌日として折り返す。
    public static func timeText(minuteOfDay: Int) -> String {
        let normalized = ((minuteOfDay % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}
