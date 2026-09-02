import SwiftUI
import ShiftTechoCore

/// 月カレンダー（日曜始まり）とシフト登録の入口。
@MainActor
struct CalendarTabView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let environment: AppEnvironment
    @State private var adMob = AdMobProvider.shared

    @State private var month: CalendarMonth
    @State private var selectedDayKey: String?
    @State private var bulkStartDayKey: String?
    @State private var showsBulkEntry = false
    @State private var showsShare = false
    @State private var revision = 0
    @State private var undoTitle: String?

    init(environment: AppEnvironment) {
        self.environment = environment
        _month = State(initialValue: CalendarMonth.containing(environment.clock.now))
    }

    private var store: ShiftTechoStore { environment.store }

    private var assignments: [String: ShiftAssignment] {
        store.assignments(dayKeys: month.dayKeys)
    }

    private var holidays: [String: String] {
        JapaneseHolidayCalendar.holidays(year: month.year, month: month.month)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShiftTechoBackground()
                VStack(spacing: ShiftTechoTheme.Spacing.s) {
                    header
                    weekdayHeader
                    monthGrid
                    legend
                    Spacer(minLength: 0)
                    if adMob.canShowAds, !environment.isTestingMode, !environment.entitlements.isPro {
                        AdMobBannerView(adUnitID: AdMobProvider.bannerAdUnitID)
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("calendarBannerAd")
                    }
                }
                .padding(.horizontal, ShiftTechoTheme.Spacing.m)
                .padding(.top, ShiftTechoTheme.Spacing.s)
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("今日") { withAnimation { month = CalendarMonth.containing(environment.clock.now) } }
                        .accessibilityIdentifier("todayButton")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showsBulkEntry = true
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                    .accessibilityLabel("まとめて登録")
                    .accessibilityIdentifier("bulkEntryButton")

                    Button {
                        showsShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("画像を共有")
                    .accessibilityIdentifier("shareButton")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let undoTitle {
                    UndoBar(title: undoTitle) {
                        store.undoLastChange()
                        self.undoTitle = nil
                        refresh()
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .sheet(item: Binding(get: { selectedDayKey.map(DayKeyBox.init) }, set: { selectedDayKey = $0?.dayKey })) { box in
                DayShiftEditorView(environment: environment, dayKey: box.dayKey) { title in
                    showUndo(title)
                    refresh()
                }
            }
            .sheet(isPresented: $showsBulkEntry) {
                BulkShiftEntryView(environment: environment, initialDayKey: bulkStartDayKey ?? month.dayKeys.first ?? environment.todayDayKey) { title in
                    showUndo(title)
                    refresh()
                }
            }
            .sheet(isPresented: $showsShare) {
                ShiftShareView(month: month, assignments: assignments, holidays: holidays)
            }
        }
    }

    // MARK: - 部品

    private var header: some View {
        HStack {
            Button {
                withAnimation { month = month.adding(months: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: ShiftTechoTheme.minimumTapTarget, height: ShiftTechoTheme.minimumTapTarget)
            }
            .accessibilityLabel("前の月")
            .accessibilityIdentifier("previousMonthButton")

            Spacer()
            Text(month.title)
                .font(ShiftTechoTheme.titleFont)
                .accessibilityIdentifier("monthTitle")
            Spacer()

            Button {
                withAnimation { month = month.adding(months: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: ShiftTechoTheme.minimumTapTarget, height: ShiftTechoTheme.minimumTapTarget)
            }
            .accessibilityLabel("次の月")
            .accessibilityIdentifier("nextMonthButton")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(1...7, id: \.self) { weekday in
                Text(ShiftTechoCalendar.weekdaySymbol(weekday: weekday))
                    .font(ShiftTechoTheme.captionFont.weight(.semibold))
                    .foregroundStyle(weekdayColor(weekday))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var monthGrid: some View {
        let assignments = self.assignments
        let holidays = self.holidays
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(month.days) { day in
                if let dayKey = day.dayKey {
                    CalendarDayCell(
                        day: day,
                        dayKey: dayKey,
                        assignment: assignments[dayKey],
                        holidayName: holidays[dayKey],
                        isToday: dayKey == environment.todayDayKey
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectedDayKey = dayKey }
                    .onLongPressGesture {
                        bulkStartDayKey = dayKey
                        showsBulkEntry = true
                    }
                    .accessibilityIdentifier("day-\(dayKey)")
                } else {
                    Color.clear.frame(height: 62)
                }
            }
        }
        // 左右スワイプでも月を移動できる（ボタンも残す）。
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    withAnimation { month = month.adding(months: value.translation.width < 0 ? 1 : -1) }
                }
        )
        .id("\(month.year)-\(month.month)-\(revision)")
    }

    private var legend: some View {
        let used = assignments.values
            .map(\.definition)
            .reduce(into: [ShiftDefinition]()) { result, definition in
                if !result.contains(where: { $0.name == definition.name }) { result.append(definition) }
            }
        return Group {
            if used.isEmpty {
                ShiftTechoEmptyState(
                    symbol: "calendar.badge.plus",
                    title: "まだシフトがありません",
                    message: "日付をタップしてシフトを登録しましょう"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ShiftTechoTheme.Spacing.m) {
                        ForEach(used, id: \.name) { definition in
                            ShiftLegendRow(
                                name: definition.name,
                                color: definition.color,
                                isRest: definition.kind == .rest
                            )
                        }
                    }
                    .padding(.vertical, ShiftTechoTheme.Spacing.xs)
                }
            }
        }
    }

    private func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: ShiftTechoTheme.sundayText(colorScheme)
        case 7: ShiftTechoTheme.saturdayText(colorScheme)
        default: ShiftTechoTheme.primaryText(colorScheme)
        }
    }

    private func refresh() {
        revision += 1
        Task { await environment.refreshNotifications() }
    }

    private func showUndo(_ title: String) {
        undoTitle = title
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if undoTitle == title {
                undoTitle = nil
                store.clearUndo()
            }
        }
    }
}

/// `sheet(item:)` に渡すための dayKey ラッパー。
struct DayKeyBox: Identifiable, Hashable {
    let dayKey: String
    var id: String { dayKey }
}

/// 1 マス。色に加えて文字と記号で状態を示す。
struct CalendarDayCell: View {
    @Environment(\.colorScheme) private var colorScheme

    let day: CalendarDay
    let dayKey: String
    let assignment: ShiftAssignment?
    let holidayName: String?
    let isToday: Bool

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("\(day.day ?? 0)")
                    .font(ShiftTechoTheme.captionFont.weight(isToday ? .bold : .regular))
                    .foregroundStyle(numberColor)
                if holidayName != nil {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(ShiftTechoTheme.sundayText(colorScheme))
                }
            }
            if let assignment {
                ShiftLabelChip(definition: assignment.definition, compact: true)
                if !assignment.note.isEmpty {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("－")
                    .font(ShiftTechoTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(2)
        .frame(height: 62)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ShiftTechoTheme.cardFill(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isToday ? ShiftTechoTheme.accent : ShiftTechoTheme.cardStroke(colorScheme), lineWidth: isToday ? 2 : 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("タップしてシフトを編集。長押しでまとめて登録。")
    }

    private var numberColor: Color {
        if holidayName != nil || day.isSunday { return ShiftTechoTheme.sundayText(colorScheme) }
        if day.isSaturday { return ShiftTechoTheme.saturdayText(colorScheme) }
        return ShiftTechoTheme.primaryText(colorScheme)
    }

    private var accessibilityText: String {
        var parts: [String] = ["\(day.day ?? 0)日"]
        if let holidayName { parts.append(holidayName) }
        if let assignment {
            let definition = assignment.definition
            parts.append(definition.kind == .rest ? "休み" : definition.name)
            if let range = definition.timeRangeText { parts.append(range) }
        } else {
            parts.append("未設定")
        }
        if isToday { parts.append("今日") }
        return parts.joined(separator: "、")
    }
}
