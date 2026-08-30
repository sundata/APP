import Foundation

/// 給与ルール。金額は円の非負整数、割増は基準点（25% = 2500）で持つ。
public struct PayrollSettings: Codable, Hashable, Sendable {
    public static let premiumBasisPointsRange = 0...20_000
    public static let defaultNightStartMinute = 22 * 60
    public static let defaultNightEndMinute = 5 * 60

    /// 基礎時給（円）。未設定なら nil で、金額は表示しない。
    public var hourlyWageYen: Int?
    /// 深夜割増（2500 = 25%）。
    public var nightPremiumBasisPoints: Int
    /// 残業割増（2500 = 25%）。
    public var overtimePremiumBasisPoints: Int
    /// 深夜時間帯の開始・終了（0 時からの経過分）。日をまたぐ設定を許す。
    public var nightStartMinute: Int
    public var nightEndMinute: Int
    /// 1 日の所定労働時間（分）。
    public var standardDailyMinutes: Int
    /// 勤務日 1 日あたりの交通費（円）。
    public var transportAllowancePerWorkdayYen: Int

    public init(
        hourlyWageYen: Int? = nil,
        nightPremiumBasisPoints: Int = 2500,
        overtimePremiumBasisPoints: Int = 2500,
        nightStartMinute: Int = PayrollSettings.defaultNightStartMinute,
        nightEndMinute: Int = PayrollSettings.defaultNightEndMinute,
        standardDailyMinutes: Int = 8 * 60,
        transportAllowancePerWorkdayYen: Int = 0
    ) {
        self.hourlyWageYen = hourlyWageYen.map { max(0, $0) }
        self.nightPremiumBasisPoints = Self.clampPremium(nightPremiumBasisPoints)
        self.overtimePremiumBasisPoints = Self.clampPremium(overtimePremiumBasisPoints)
        self.nightStartMinute = Self.clampMinuteOfDay(nightStartMinute)
        self.nightEndMinute = Self.clampMinuteOfDay(nightEndMinute)
        self.standardDailyMinutes = max(0, min(standardDailyMinutes, 24 * 60))
        self.transportAllowancePerWorkdayYen = max(0, transportAllowancePerWorkdayYen)
    }

    public static func clampPremium(_ value: Int) -> Int {
        min(max(value, premiumBasisPointsRange.lowerBound), premiumBasisPointsRange.upperBound)
    }

    public static func clampMinuteOfDay(_ value: Int) -> Int {
        min(max(value, 0), 24 * 60 - 1)
    }

    /// 深夜時間帯が日をまたぐか（22:00〜05:00 など）。
    public var nightWindowCrossesMidnight: Bool {
        nightEndMinute <= nightStartMinute
    }
}
