import Foundation

/// 月カレンダーのマス。UI に依存しないので単体テストできる。
public struct CalendarDay: Identifiable, Hashable, Sendable {
    /// 月内の日。前後の空白マスでは nil。
    public let day: Int?
    /// `yyyy-MM-dd`。空白マスでは nil。
    public let dayKey: String?
    /// 1 = 日曜 ... 7 = 土曜。
    public let weekday: Int
    public let id: String

    init(day: Int?, dayKey: String?, weekday: Int, id: String) {
        self.day = day
        self.dayKey = dayKey
        self.weekday = weekday
        self.id = id
    }

    public var isPlaceholder: Bool { dayKey == nil }
    public var isSunday: Bool { weekday == 1 }
    public var isSaturday: Bool { weekday == 7 }
}

/// 日曜はじまりの 1 か月分のマス。
public struct CalendarMonth: Sendable {
    public let year: Int
    public let month: Int
    public let days: [CalendarDay]

    public init(year: Int, month: Int, calendar: Calendar = ShiftTechoCalendar.japan) {
        self.year = year
        self.month = month

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let first = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: first) else {
            self.days = []
            return
        }

        let leading = calendar.component(.weekday, from: first) - 1
        var days = (0..<leading).map { index in
            CalendarDay(day: nil, dayKey: nil, weekday: index + 1, id: "leading-\(year)-\(month)-\(index)")
        }
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: first) else { continue }
            let key = ShiftTechoCalendar.dayKey(for: date, calendar: calendar)
            days.append(
                CalendarDay(
                    day: day,
                    dayKey: key,
                    weekday: calendar.component(.weekday, from: date),
                    id: key
                )
            )
        }
        // 末尾も 7 の倍数までそろえて、グリッドの高さを安定させる。
        let trailing = (7 - days.count % 7) % 7
        for index in 0..<trailing {
            let weekday = (days.count + index) % 7 + 1
            days.append(CalendarDay(day: nil, dayKey: nil, weekday: weekday, id: "trailing-\(year)-\(month)-\(index)"))
        }
        self.days = days
    }

    /// 月内の実際の日付キー（空白マスを除く）。
    public var dayKeys: [String] {
        days.compactMap(\.dayKey)
    }

    public var title: String {
        "\(year)年\(month)月"
    }

    /// 指定日が含まれる月。
    public static func containing(_ date: Date, calendar: Calendar = ShiftTechoCalendar.japan) -> CalendarMonth {
        let components = calendar.dateComponents([.year, .month], from: date)
        return CalendarMonth(year: components.year ?? 1970, month: components.month ?? 1, calendar: calendar)
    }

    /// 月送り。
    public func adding(months: Int, calendar: Calendar = ShiftTechoCalendar.japan) -> CalendarMonth {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let base = calendar.date(from: components),
              let shifted = calendar.date(byAdding: .month, value: months, to: base) else { return self }
        return .containing(shifted, calendar: calendar)
    }
}
