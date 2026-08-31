import Foundation

/// 日本の祝日。オンライン API に依存せず、決定的な計算だけで求める。
/// 春分・秋分は 1980〜2099 年で有効な近似式（国立天文台の暦要項と一致する範囲）を使う。
public enum JapaneseHolidayCalendar {
    public static let supportedYears = 1980...2099

    /// その年の祝日（`yyyy-MM-dd` → 名称）。
    public static func holidays(year: Int) -> [String: String] {
        guard supportedYears.contains(year) else { return [:] }

        var result: [Int: String] = [:] // 通し日（1 月 1 日 = 1）→ 名称
        func add(month: Int, day: Int, _ name: String) {
            guard let ordinal = ordinal(year: year, month: month, day: day) else { return }
            result[ordinal] = name
        }

        add(month: 1, day: 1, "元日")
        if year >= 2000 {
            add(month: 1, day: nthWeekday(year: year, month: 1, weekday: 2, nth: 2), "成人の日")
        } else {
            add(month: 1, day: 15, "成人の日")
        }

        add(month: 2, day: 11, "建国記念の日")
        if year >= 2020 {
            add(month: 2, day: 23, "天皇誕生日")
        }

        add(month: 3, day: vernalEquinoxDay(year: year), "春分の日")

        if year >= 2007 {
            add(month: 4, day: 29, "昭和の日")
        } else {
            add(month: 4, day: 29, "みどりの日")
        }
        if year == 2019 {
            add(month: 5, day: 1, "天皇の即位の日")
        }

        add(month: 5, day: 3, "憲法記念日")
        if year >= 2007 {
            add(month: 5, day: 4, "みどりの日")
        }
        add(month: 5, day: 5, "こどもの日")

        switch year {
        case 2020: add(month: 7, day: 23, "海の日")
        case 2021: add(month: 7, day: 22, "海の日")
        default:
            if year >= 2003 {
                add(month: 7, day: nthWeekday(year: year, month: 7, weekday: 2, nth: 3), "海の日")
            } else if year >= 1996 {
                add(month: 7, day: 20, "海の日")
            }
        }

        switch year {
        case 2020: add(month: 8, day: 10, "山の日")
        case 2021: add(month: 8, day: 8, "山の日")
        default:
            if year >= 2016 {
                add(month: 8, day: 11, "山の日")
            }
        }

        add(month: 9, day: nthWeekday(year: year, month: 9, weekday: 2, nth: 3), "敬老の日")
        add(month: 9, day: autumnalEquinoxDay(year: year), "秋分の日")

        switch year {
        case 2020: add(month: 7, day: 24, "スポーツの日")
        case 2021: add(month: 7, day: 23, "スポーツの日")
        default:
            let name = year >= 2020 ? "スポーツの日" : "体育の日"
            if year >= 2000 {
                add(month: 10, day: nthWeekday(year: year, month: 10, weekday: 2, nth: 2), name)
            } else {
                add(month: 10, day: 10, name)
            }
        }

        add(month: 11, day: 3, "文化の日")
        if year == 2019 {
            add(month: 10, day: 22, "即位礼正殿の儀")
        }
        add(month: 11, day: 23, "勤労感謝の日")
        if year <= 2018 {
            add(month: 12, day: 23, "天皇誕生日")
        }

        let statutory = result

        // 国民の休日: 祝日にはさまれた平日（例: 2026 年 9 月 22 日）。
        for ordinal in statutory.keys.sorted() {
            let candidate = ordinal + 1
            guard statutory[candidate] == nil,
                  statutory[candidate + 1] != nil,
                  let date = self.date(year: year, ordinal: candidate),
                  ShiftTechoCalendar.weekday(for: date) != 1 else { continue }
            result[candidate] = "国民の休日"
        }

        // 振替休日: 祝日が日曜のとき、次の祝日でない日を休日にする。
        for ordinal in statutory.keys.sorted() {
            guard let date = self.date(year: year, ordinal: ordinal),
                  ShiftTechoCalendar.weekday(for: date) == 1 else { continue }
            var cursor = ordinal + 1
            while result[cursor] != nil {
                cursor += 1
            }
            guard self.date(year: year, ordinal: cursor) != nil else { continue }
            result[cursor] = "振替休日"
        }

        var byDayKey: [String: String] = [:]
        for (ordinal, name) in result {
            guard let date = self.date(year: year, ordinal: ordinal) else { continue }
            byDayKey[ShiftTechoCalendar.dayKey(for: date)] = name
        }
        return byDayKey
    }

    /// 指定した月の祝日だけを返す。
    public static func holidays(year: Int, month: Int) -> [String: String] {
        let prefix = String(format: "%04d-%02d", year, month)
        return holidays(year: year).filter { $0.key.hasPrefix(prefix) }
    }

    /// その日が祝日なら名称を返す。
    public static func holidayName(dayKey: String) -> String? {
        guard let parsed = ShiftTechoCalendar.components(fromDayKey: dayKey) else { return nil }
        return holidays(year: parsed.year)[dayKey]
    }

    public static func isHoliday(dayKey: String) -> Bool {
        holidayName(dayKey: dayKey) != nil
    }

    /// 春分の日（1980〜2099 年）。
    public static func vernalEquinoxDay(year: Int) -> Int {
        equinoxDay(year: year, base: 20.8431)
    }

    /// 秋分の日（1980〜2099 年）。
    public static func autumnalEquinoxDay(year: Int) -> Int {
        equinoxDay(year: year, base: 23.2488)
    }

    private static func equinoxDay(year: Int, base: Double) -> Int {
        let offset = Double(year - 1980)
        let value = base + 0.242194 * offset - Double((year - 1980) / 4)
        return Int(value.rounded(.down))
    }

    /// 指定月の第 n・指定曜日（weekday は 1 = 日曜）。
    private static func nthWeekday(year: Int, month: Int, weekday: Int, nth: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let first = ShiftTechoCalendar.japan.date(from: components) else { return 1 }
        let firstWeekday = ShiftTechoCalendar.weekday(for: first)
        let delta = (weekday - firstWeekday + 7) % 7
        return 1 + delta + (nth - 1) * 7
    }

    /// 1 月 1 日を 1 とする年内通し日。存在しない日付では nil。
    private static func ordinal(year: Int, month: Int, day: Int) -> Int? {
        let calendar = ShiftTechoCalendar.japan
        guard let date = ShiftTechoCalendar.date(fromDayKey: ShiftTechoCalendar.dayKey(year: year, month: month, day: day), calendar: calendar) else {
            return nil
        }
        return calendar.ordinality(of: .day, in: .year, for: date)
    }

    private static func date(year: Int, ordinal: Int) -> Date? {
        let calendar = ShiftTechoCalendar.japan
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        guard let first = calendar.date(from: components),
              let date = calendar.date(byAdding: .day, value: ordinal - 1, to: first),
              calendar.component(.year, from: date) == year else { return nil }
        return date
    }
}
