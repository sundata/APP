import Foundation

/// 1 日分の勤務時間の内訳。分単位の整数で持ち、丸めは金額計算の最後だけで行う。
public struct DailyWorkBreakdown: Hashable, Sendable {
    public let dayKey: String
    public let billableMinutes: Int
    public let nightMinutes: Int
    public let overtimeMinutes: Int

    public init(dayKey: String, billableMinutes: Int, nightMinutes: Int, overtimeMinutes: Int) {
        self.dayKey = dayKey
        self.billableMinutes = billableMinutes
        self.nightMinutes = nightMinutes
        self.overtimeMinutes = overtimeMinutes
    }
}

/// 月次の集計結果。時給が未設定のときは金額（`...Yen`）がすべて nil になる。
public struct MonthlyPayrollSummary: Hashable, Sendable {
    public let workDayCount: Int
    public let restDayCount: Int
    public let unsetDayCount: Int
    public let totalBillableMinutes: Int
    public let nightMinutes: Int
    public let overtimeMinutes: Int
    public let baseWageYen: Int?
    public let nightPremiumYen: Int?
    public let overtimePremiumYen: Int?
    public let transportAllowanceYen: Int?
    public let estimatedTotalYen: Int?

    public var hasWageEstimate: Bool { estimatedTotalYen != nil }
}

/// 勤務時間と概算給与の計算。UI もフレームワークも知らない純粋なロジック。
public enum PayrollCalculator {
    /// 深夜時間帯と実際に重なる分数。休憩は差し引いた実働分を上限にする。
    public static func nightMinutes(for definition: ShiftDefinition, settings: PayrollSettings) -> Int {
        let span = definition.spanMinutes
        guard definition.kind == .work, span > 0, let start = definition.startMinute else { return 0 }
        let shiftStart = start
        let shiftEnd = start + span

        var overlap = 0
        // 深夜時間帯は毎日くり返すため、前後の日の窓も含めて重なりを足し合わせる。
        for dayOffset in -1...2 {
            let base = dayOffset * 1440
            let windowStart = base + settings.nightStartMinute
            let windowEnd = base + settings.nightEndMinute + (settings.nightWindowCrossesMidnight ? 1440 : 0)
            overlap += max(0, min(shiftEnd, windowEnd) - max(shiftStart, windowStart))
        }
        return min(overlap, definition.billableMinutes)
    }

    /// 1 日分の内訳。残業は「その日の実働が所定労働時間を超えた分」。
    public static func breakdown(dayKey: String, definition: ShiftDefinition, settings: PayrollSettings) -> DailyWorkBreakdown {
        let billable = definition.billableMinutes
        return DailyWorkBreakdown(
            dayKey: dayKey,
            billableMinutes: billable,
            nightMinutes: nightMinutes(for: definition, settings: settings),
            overtimeMinutes: max(0, billable - settings.standardDailyMinutes)
        )
    }

    /// 月次集計。`daysInMonth` は対象月の日数で、未設定日数を出すために使う。
    public static func monthlySummary(
        assignments: [ShiftAssignment],
        daysInMonth: Int,
        settings: PayrollSettings
    ) -> MonthlyPayrollSummary {
        let workAssignments = assignments.filter { $0.definition.kind == .work }
        let restCount = assignments.count - workAssignments.count
        let breakdowns = workAssignments.map { breakdown(dayKey: $0.dayKey, definition: $0.definition, settings: settings) }

        let totalBillable = breakdowns.reduce(0) { $0 + $1.billableMinutes }
        let totalNight = breakdowns.reduce(0) { $0 + $1.nightMinutes }
        let totalOvertime = breakdowns.reduce(0) { $0 + $1.overtimeMinutes }

        var baseWage: Int?
        var nightPremium: Int?
        var overtimePremium: Int?
        var transport: Int?
        var total: Int?

        if let wage = settings.hourlyWageYen {
            // 円 × 分の整数で持ち、最後に 1 度だけ四捨五入する。
            let base = roundedYen(numerator: wage * totalBillable, denominator: 60)
            let night = roundedYen(numerator: wage * totalNight * settings.nightPremiumBasisPoints, denominator: 60 * 10_000)
            let overtime = roundedYen(numerator: wage * totalOvertime * settings.overtimePremiumBasisPoints, denominator: 60 * 10_000)
            let allowance = settings.transportAllowancePerWorkdayYen * workAssignments.count
            baseWage = base
            nightPremium = night
            overtimePremium = overtime
            transport = allowance
            total = base + night + overtime + allowance
        }

        return MonthlyPayrollSummary(
            workDayCount: workAssignments.count,
            restDayCount: restCount,
            unsetDayCount: max(0, daysInMonth - assignments.count),
            totalBillableMinutes: totalBillable,
            nightMinutes: totalNight,
            overtimeMinutes: totalOvertime,
            baseWageYen: baseWage,
            nightPremiumYen: nightPremium,
            overtimePremiumYen: overtimePremium,
            transportAllowanceYen: transport,
            estimatedTotalYen: total
        )
    }

    /// 円は四捨五入して整数にする（負の値は扱わない）。
    public static func roundedYen(numerator: Int, denominator: Int) -> Int {
        guard denominator > 0 else { return 0 }
        let value = max(0, numerator)
        return (value * 2 + denominator) / (denominator * 2)
    }

    /// 分を「7時間30分」の形にする。
    public static func durationText(minutes: Int) -> String {
        let normalized = max(0, minutes)
        let hours = normalized / 60
        let remainder = normalized % 60
        return remainder == 0 ? "\(hours)時間" : "\(hours)時間\(remainder)分"
    }
}
