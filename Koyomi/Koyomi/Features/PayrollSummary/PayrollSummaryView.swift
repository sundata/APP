import SwiftUI
import KoyomiCore

/// 月の勤務時間と概算給与。金額はセンシティブなので隠す設定も用意する。
@MainActor
struct PayrollSummaryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private let environment: AppEnvironment

    @State private var month: CalendarMonth
    @State private var isRedacted = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _month = State(initialValue: CalendarMonth.containing(environment.clock.now))
    }

    private var store: KoyomiStore { environment.store }

    private var summary: MonthlyPayrollSummary {
        PayrollCalculator.monthlySummary(
            assignments: Array(store.assignments(dayKeys: month.dayKeys).values),
            daysInMonth: month.dayKeys.count,
            settings: store.settings().payrollSettings
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KoyomiBackground()
                ScrollView {
                    VStack(spacing: KoyomiTheme.Spacing.m) {
                        monthSwitcher
                        timeCard
                        wageCard
                        disclaimer
                    }
                    .padding(KoyomiTheme.Spacing.m)
                }
            }
            .navigationTitle("集計")
            .navigationBarTitleDisplayMode(.inline)
        }
        // 金額はプライバシー配慮のため、非アクティブ時に隠せるようにする。
        .onChange(of: scenePhase) { _, phase in
            guard store.settings().hidesAmountsWhenInactive else { return }
            isRedacted = phase != .active
        }
    }

    private var monthSwitcher: some View {
        HStack {
            Button {
                month = month.adding(months: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: KoyomiTheme.minimumTapTarget, height: KoyomiTheme.minimumTapTarget)
            }
            .accessibilityLabel("前の月")

            Spacer()
            Text(month.title)
                .font(KoyomiTheme.titleFont)
                .accessibilityIdentifier("summaryMonthTitle")
            Spacer()

            Button {
                month = month.adding(months: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: KoyomiTheme.minimumTapTarget, height: KoyomiTheme.minimumTapTarget)
            }
            .accessibilityLabel("次の月")
        }
    }

    private var timeCard: some View {
        let summary = self.summary
        return KoyomiCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                Text("勤務時間")
                    .font(KoyomiTheme.headlineFont)
                SummaryRow(title: "勤務日数", value: "\(summary.workDayCount)日", identifier: "summaryWorkDays")
                SummaryRow(title: "休みの日数", value: "\(summary.restDayCount)日", identifier: "summaryRestDays")
                SummaryRow(title: "未設定の日数", value: "\(summary.unsetDayCount)日", identifier: "summaryUnsetDays")
                Divider()
                SummaryRow(
                    title: "計上時間",
                    value: PayrollCalculator.durationText(minutes: summary.totalBillableMinutes),
                    identifier: "summaryBillableHours"
                )
                SummaryRow(
                    title: "深夜時間",
                    value: PayrollCalculator.durationText(minutes: summary.nightMinutes),
                    identifier: "summaryNightHours"
                )
                SummaryRow(
                    title: "残業時間",
                    value: PayrollCalculator.durationText(minutes: summary.overtimeMinutes),
                    identifier: "summaryOvertimeHours"
                )
            }
        }
    }

    @ViewBuilder
    private var wageCard: some View {
        let summary = self.summary
        KoyomiCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                Text("概算給与")
                    .font(KoyomiTheme.headlineFont)
                if let total = summary.estimatedTotalYen {
                    SummaryRow(title: "基本給", value: yen(summary.baseWageYen), identifier: "summaryBaseWage")
                    SummaryRow(title: "深夜手当", value: yen(summary.nightPremiumYen), identifier: "summaryNightPremium")
                    SummaryRow(title: "残業手当", value: yen(summary.overtimePremiumYen), identifier: "summaryOvertimePremium")
                    SummaryRow(title: "交通費", value: yen(summary.transportAllowanceYen), identifier: "summaryTransport")
                    Divider()
                    SummaryRow(
                        title: "予想合計",
                        value: yen(total),
                        identifier: "summaryEstimatedTotal",
                        emphasized: true
                    )
                } else {
                    Text("時給を設定すると表示されます")
                        .font(KoyomiTheme.bodyFont)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("summaryWageMissingHint")
                }
            }
        }
        .redacted(reason: isRedacted ? .placeholder : [])
    }

    private var disclaimer: some View {
        Text("表示金額は概算です。実際の給与・税金・社会保険料とは異なる場合があります。")
            .font(KoyomiTheme.captionFont)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("summaryDisclaimer")
    }

    private func yen(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.grouping(.automatic))) 円"
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String
    let identifier: String
    var emphasized = false

    var body: some View {
        HStack {
            Text(title)
                .font(KoyomiTheme.bodyFont)
            Spacer(minLength: KoyomiTheme.Spacing.s)
            Text(value)
                .font(emphasized ? KoyomiTheme.headlineFont : KoyomiTheme.bodyFont)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
