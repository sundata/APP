import XCTest
@testable import ShiftTechoCore

final class PayrollCalculatorTests: XCTestCase {
    private let settings = PayrollSettings(hourlyWageYen: 1_200)

    private func dayShift() -> ShiftDefinition {
        ShiftDefinition(name: "日勤", kind: .work, startMinute: 9 * 60, endMinute: 18 * 60, breakMinutes: 60)
    }

    private func nightShift() -> ShiftDefinition {
        ShiftDefinition(
            name: "夜勤",
            kind: .work,
            startMinute: 22 * 60,
            endMinute: 7 * 60,
            crossesMidnight: true,
            breakMinutes: 60
        )
    }

    func testDayShiftBillableMinutes() {
        XCTAssertEqual(dayShift().spanMinutes, 540)
        XCTAssertEqual(dayShift().billableMinutes, 480)
    }

    func testNightShiftCrossingMidnightDuration() {
        XCTAssertEqual(nightShift().spanMinutes, 540)
        XCTAssertEqual(nightShift().billableMinutes, 480)
    }

    func testNightWindowIntersectionForNightShift() {
        // 22:00〜翌 07:00 のうち深夜（22:00〜05:00）は 7 時間。
        XCTAssertEqual(PayrollCalculator.nightMinutes(for: nightShift(), settings: settings), 420)
    }

    func testPartialNightOverlap() {
        // 20:00〜24:00 のうち深夜は 22:00 以降の 2 時間。
        let evening = ShiftDefinition(name: "遅番", kind: .work, startMinute: 20 * 60, endMinute: 24 * 60, breakMinutes: 0)
        XCTAssertEqual(PayrollCalculator.nightMinutes(for: evening, settings: settings), 120)

        // 03:00〜08:00 のうち深夜は 05:00 までの 2 時間。
        let earlyMorning = ShiftDefinition(name: "早朝", kind: .work, startMinute: 3 * 60, endMinute: 8 * 60, breakMinutes: 0)
        XCTAssertEqual(PayrollCalculator.nightMinutes(for: earlyMorning, settings: settings), 120)
    }

    func testNoNightOverlapForDayShift() {
        XCTAssertEqual(PayrollCalculator.nightMinutes(for: dayShift(), settings: settings), 0)
    }

    func testZeroAndNegativeDurationsAreTreatedAsZero() {
        let zero = ShiftDefinition(name: "ゼロ", kind: .work, startMinute: 9 * 60, endMinute: 9 * 60, breakMinutes: 0)
        XCTAssertEqual(zero.spanMinutes, 0)
        XCTAssertEqual(zero.billableMinutes, 0)

        // 日をまたぐフラグがない逆順の時刻は 0 分として扱う。
        let negative = ShiftDefinition(name: "不正", kind: .work, startMinute: 22 * 60, endMinute: 7 * 60, breakMinutes: 0)
        XCTAssertEqual(negative.spanMinutes, 0)
        XCTAssertEqual(negative.billableMinutes, 0)

        // 休憩が拘束時間より長くても負にならない。
        let overBreak = ShiftDefinition(name: "休憩過多", kind: .work, startMinute: 9 * 60, endMinute: 12 * 60, breakMinutes: 240)
        XCTAssertEqual(overBreak.billableMinutes, 0)

        XCTAssertEqual(PayrollCalculator.nightMinutes(for: zero, settings: settings), 0)
    }

    func testOvertimeOverEightHours() {
        let long = ShiftDefinition(name: "長日勤", kind: .work, startMinute: 9 * 60, endMinute: 21 * 60, breakMinutes: 60)
        let breakdown = PayrollCalculator.breakdown(dayKey: "2026-04-01", definition: long, settings: settings)
        XCTAssertEqual(breakdown.billableMinutes, 660)
        XCTAssertEqual(breakdown.overtimeMinutes, 180)
    }

    func testNightAndOvertimePremiumsStack() {
        // 夜勤 1 日: 実働 480 分・深夜 420 分・残業 0 分。
        let nightOnly = PayrollCalculator.monthlySummary(
            assignments: [assignment(dayKey: "2026-04-01", definition: nightShift())],
            daysInMonth: 30,
            settings: settings
        )
        XCTAssertEqual(nightOnly.totalBillableMinutes, 480)
        XCTAssertEqual(nightOnly.nightMinutes, 420)
        XCTAssertEqual(nightOnly.overtimeMinutes, 0)
        XCTAssertEqual(nightOnly.baseWageYen, 9_600)
        XCTAssertEqual(nightOnly.nightPremiumYen, 2_100)
        XCTAssertEqual(nightOnly.estimatedTotalYen, 11_700)

        // 20:00〜翌 08:00 休憩 60 分: 実働 660 分・深夜 420 分・残業 180 分。
        let longNight = ShiftDefinition(
            name: "長夜勤",
            kind: .work,
            startMinute: 20 * 60,
            endMinute: 8 * 60,
            crossesMidnight: true,
            breakMinutes: 60
        )
        let stacked = PayrollCalculator.monthlySummary(
            assignments: [assignment(dayKey: "2026-04-02", definition: longNight)],
            daysInMonth: 30,
            settings: settings
        )
        XCTAssertEqual(stacked.totalBillableMinutes, 660)
        XCTAssertEqual(stacked.nightMinutes, 420)
        XCTAssertEqual(stacked.overtimeMinutes, 180)
        XCTAssertEqual(stacked.baseWageYen, 13_200)
        XCTAssertEqual(stacked.nightPremiumYen, 2_100)
        XCTAssertEqual(stacked.overtimePremiumYen, 900)
        XCTAssertEqual(stacked.estimatedTotalYen, 16_200)
    }

    func testTransportAllowanceCountsWorkdaysOnly() {
        let withAllowance = PayrollSettings(hourlyWageYen: 1_000, transportAllowancePerWorkdayYen: 500)
        let summary = PayrollCalculator.monthlySummary(
            assignments: [
                assignment(dayKey: "2026-04-01", definition: dayShift()),
                assignment(dayKey: "2026-04-02", definition: dayShift()),
                assignment(dayKey: "2026-04-03", definition: ShiftDefinition(name: "休み", kind: .rest, color: .gray))
            ],
            daysInMonth: 30,
            settings: withAllowance
        )
        XCTAssertEqual(summary.workDayCount, 2)
        XCTAssertEqual(summary.restDayCount, 1)
        XCTAssertEqual(summary.unsetDayCount, 27)
        XCTAssertEqual(summary.transportAllowanceYen, 1_000)
        XCTAssertEqual(summary.baseWageYen, 16_000)
        XCTAssertEqual(summary.estimatedTotalYen, 17_000)
    }

    func testMinutesOnlyWithoutHourlyWage() {
        let summary = PayrollCalculator.monthlySummary(
            assignments: [assignment(dayKey: "2026-04-01", definition: nightShift())],
            daysInMonth: 30,
            settings: PayrollSettings()
        )
        XCTAssertEqual(summary.totalBillableMinutes, 480)
        XCTAssertEqual(summary.nightMinutes, 420)
        XCTAssertNil(summary.baseWageYen)
        XCTAssertNil(summary.nightPremiumYen)
        XCTAssertNil(summary.overtimePremiumYen)
        XCTAssertNil(summary.transportAllowanceYen)
        XCTAssertNil(summary.estimatedTotalYen)
        XCTAssertFalse(summary.hasWageEstimate)
    }

    func testYenRoundingIsHalfUp() {
        XCTAssertEqual(PayrollCalculator.roundedYen(numerator: 3, denominator: 2), 2)
        XCTAssertEqual(PayrollCalculator.roundedYen(numerator: 7, denominator: 5), 1)
        XCTAssertEqual(PayrollCalculator.roundedYen(numerator: 8, denominator: 5), 2)
        XCTAssertEqual(PayrollCalculator.roundedYen(numerator: -100, denominator: 60), 0)

        // 時給 1,010 円で 30 分 = 505 円ちょうど。
        let halfHour = ShiftDefinition(name: "短時間", kind: .work, startMinute: 9 * 60, endMinute: 9 * 60 + 30, breakMinutes: 0)
        let summary = PayrollCalculator.monthlySummary(
            assignments: [assignment(dayKey: "2026-04-01", definition: halfHour)],
            daysInMonth: 30,
            settings: PayrollSettings(hourlyWageYen: 1_010)
        )
        XCTAssertEqual(summary.baseWageYen, 505)

        // 時給 1,001 円で 20 分 = 333.67 円 → 334 円。
        let twentyMinutes = ShiftDefinition(name: "20分", kind: .work, startMinute: 9 * 60, endMinute: 9 * 60 + 20, breakMinutes: 0)
        let rounded = PayrollCalculator.monthlySummary(
            assignments: [assignment(dayKey: "2026-04-01", definition: twentyMinutes)],
            daysInMonth: 30,
            settings: PayrollSettings(hourlyWageYen: 1_001)
        )
        XCTAssertEqual(rounded.baseWageYen, 334)
    }

    func testRestDayHasNoMinutesOrMoney() {
        let rest = ShiftDefinition(name: "休み", kind: .rest, startMinute: 9 * 60, endMinute: 18 * 60, breakMinutes: 60, color: .gray)
        XCTAssertNil(rest.startMinute)
        XCTAssertNil(rest.timeRangeText)
        XCTAssertEqual(rest.breakMinutes, 0)
        XCTAssertEqual(rest.billableMinutes, 0)

        let summary = PayrollCalculator.monthlySummary(
            assignments: [assignment(dayKey: "2026-04-01", definition: rest)],
            daysInMonth: 30,
            settings: settings
        )
        XCTAssertEqual(summary.workDayCount, 0)
        XCTAssertEqual(summary.restDayCount, 1)
        XCTAssertEqual(summary.estimatedTotalYen, 0)
    }

    func testPremiumAndWageClamping() {
        let clamped = PayrollSettings(
            hourlyWageYen: -100,
            nightPremiumBasisPoints: 30_000,
            overtimePremiumBasisPoints: -500,
            standardDailyMinutes: 5_000,
            transportAllowancePerWorkdayYen: -10
        )
        XCTAssertEqual(clamped.hourlyWageYen, 0)
        XCTAssertEqual(clamped.nightPremiumBasisPoints, 20_000)
        XCTAssertEqual(clamped.overtimePremiumBasisPoints, 0)
        XCTAssertEqual(clamped.standardDailyMinutes, 1_440)
        XCTAssertEqual(clamped.transportAllowancePerWorkdayYen, 0)
    }

    func testDurationText() {
        XCTAssertEqual(PayrollCalculator.durationText(minutes: 480), "8時間")
        XCTAssertEqual(PayrollCalculator.durationText(minutes: 450), "7時間30分")
        XCTAssertEqual(PayrollCalculator.durationText(minutes: -10), "0時間")
    }

    private func assignment(dayKey: String, definition: ShiftDefinition) -> ShiftAssignment {
        ShiftAssignment(dayKey: dayKey, templateID: nil, definition: definition)
    }
}
