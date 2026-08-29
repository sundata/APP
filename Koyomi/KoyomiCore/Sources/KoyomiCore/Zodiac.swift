import Foundation

/// 太陽星座。`rawValue` は永続化とシード計算に使う安定した識別子。
public enum Zodiac: String, CaseIterable, Codable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces

    /// 日本語表示名（UI とシェアカードで使用）。
    public var japaneseName: String {
        switch self {
        case .aries: "牡羊座"
        case .taurus: "牡牛座"
        case .gemini: "双子座"
        case .cancer: "蟹座"
        case .leo: "獅子座"
        case .virgo: "乙女座"
        case .libra: "天秤座"
        case .scorpio: "蠍座"
        case .sagittarius: "射手座"
        case .capricorn: "山羊座"
        case .aquarius: "水瓶座"
        case .pisces: "魚座"
        }
    }

    /// 表示用の期間（例: 8/23 - 9/22）。
    public var periodDescription: String {
        let range = Self.ranges[self]!
        return "\(range.startMonth)/\(range.startDay) - \(range.endMonth)/\(range.endDay)"
    }

    /// シード計算に使う安定した序数。`CaseIterable` の順序に依存しない。
    public var ordinal: Int {
        switch self {
        case .aries: 0
        case .taurus: 1
        case .gemini: 2
        case .cancer: 3
        case .leo: 4
        case .virgo: 5
        case .libra: 6
        case .scorpio: 7
        case .sagittarius: 8
        case .capricorn: 9
        case .aquarius: 10
        case .pisces: 11
        }
    }

    struct Range: Sendable {
        let startMonth: Int
        let startDay: Int
        let endMonth: Int
        let endDay: Int
    }

    static let ranges: [Zodiac: Range] = [
        .aries: .init(startMonth: 3, startDay: 21, endMonth: 4, endDay: 19),
        .taurus: .init(startMonth: 4, startDay: 20, endMonth: 5, endDay: 20),
        .gemini: .init(startMonth: 5, startDay: 21, endMonth: 6, endDay: 21),
        .cancer: .init(startMonth: 6, startDay: 22, endMonth: 7, endDay: 22),
        .leo: .init(startMonth: 7, startDay: 23, endMonth: 8, endDay: 22),
        .virgo: .init(startMonth: 8, startDay: 23, endMonth: 9, endDay: 22),
        .libra: .init(startMonth: 9, startDay: 23, endMonth: 10, endDay: 23),
        .scorpio: .init(startMonth: 10, startDay: 24, endMonth: 11, endDay: 22),
        .sagittarius: .init(startMonth: 11, startDay: 23, endMonth: 12, endDay: 21),
        .capricorn: .init(startMonth: 12, startDay: 22, endMonth: 1, endDay: 19),
        .aquarius: .init(startMonth: 1, startDay: 20, endMonth: 2, endDay: 18),
        .pisces: .init(startMonth: 2, startDay: 19, endMonth: 3, endDay: 20)
    ]

    /// 月日から太陽星座を判定する。境界日は上記の期間表に従う。
    public static func from(month: Int, day: Int) -> Zodiac {
        for zodiac in Zodiac.allCases {
            let range = ranges[zodiac]!
            if range.startMonth == range.endMonth {
                if month == range.startMonth, day >= range.startDay, day <= range.endDay { return zodiac }
            } else if range.startMonth < range.endMonth {
                if (month == range.startMonth && day >= range.startDay)
                    || (month == range.endMonth && day <= range.endDay) {
                    return zodiac
                }
            } else {
                // 年をまたぐ（山羊座）
                if (month == range.startMonth && day >= range.startDay)
                    || (month == range.endMonth && day <= range.endDay) {
                    return zodiac
                }
            }
        }
        return .capricorn
    }

    /// 誕生日（生年月日）から太陽星座を判定する。
    public static func from(date: Date, calendar: Calendar = KoyomiCalendar.japan) -> Zodiac {
        let components = calendar.dateComponents([.month, .day], from: date)
        return from(month: components.month ?? 1, day: components.day ?? 1)
    }
}
