import Foundation

/// シフトの種類。休みは勤務時間も給与も持たない。
public enum ShiftKind: String, Codable, CaseIterable, Sendable {
    case work
    case rest

    public var japaneseName: String {
        switch self {
        case .work: "勤務"
        case .rest: "休み"
        }
    }
}

/// シフトの色。コントラストを確認済みのパレットからのみ選ぶ。
public enum ShiftColor: String, Codable, CaseIterable, Sendable {
    case blue
    case green
    case orange
    case purple
    case pink
    case teal
    case brown
    case gray

    public var japaneseName: String {
        switch self {
        case .blue: "ブルー"
        case .green: "グリーン"
        case .orange: "オレンジ"
        case .purple: "パープル"
        case .pink: "ピンク"
        case .teal: "ティール"
        case .brown: "ブラウン"
        case .gray: "グレー"
        }
    }

    /// ラベル背景に使う 16 進カラー。白文字で 4.5:1 以上のコントラストを確保する。
    public var hex: String {
        switch self {
        case .blue: "#1F5FA8"
        case .green: "#1F7A45"
        case .orange: "#A65200"
        case .purple: "#5B3A9B"
        case .pink: "#A62A5B"
        case .teal: "#0F6C72"
        case .brown: "#6B4423"
        case .gray: "#4F5560"
        }
    }
}

/// シフトの内容。テンプレートにも、日ごとの記録（スナップショット）にも使う値型。
public struct ShiftDefinition: Codable, Hashable, Sendable {
    public static let nameLengthLimit = 12
    public static let breakMinutesRange = 0...480

    public var name: String
    public var kind: ShiftKind
    /// 0 時からの経過分。休みでは nil。
    public var startMinute: Int?
    public var endMinute: Int?
    public var crossesMidnight: Bool
    public var breakMinutes: Int
    public var color: ShiftColor

    public init(
        name: String,
        kind: ShiftKind,
        startMinute: Int? = nil,
        endMinute: Int? = nil,
        crossesMidnight: Bool = false,
        breakMinutes: Int = 60,
        color: ShiftColor = .blue
    ) {
        self.name = String(name.prefix(Self.nameLengthLimit))
        self.kind = kind
        self.startMinute = kind == .rest ? nil : startMinute
        self.endMinute = kind == .rest ? nil : endMinute
        self.crossesMidnight = kind == .rest ? false : crossesMidnight
        self.breakMinutes = kind == .rest ? 0 : min(max(breakMinutes, Self.breakMinutesRange.lowerBound), Self.breakMinutesRange.upperBound)
        self.color = color
    }

    /// 拘束時間（休憩を引く前）。日をまたぐ場合は 24 時間を足す。
    public var spanMinutes: Int {
        guard kind == .work, let startMinute, let endMinute else { return 0 }
        let raw = endMinute - startMinute + (crossesMidnight ? 1440 : 0)
        return max(0, raw)
    }

    /// 給与計算の対象になる実働分。
    public var billableMinutes: Int {
        max(0, spanMinutes - breakMinutes)
    }

    /// 表示用の時間帯（例: 22:00〜07:00）。休みでは nil。
    public var timeRangeText: String? {
        guard kind == .work, let startMinute, let endMinute else { return nil }
        return "\(KoyomiCalendar.timeText(minuteOfDay: startMinute))〜\(KoyomiCalendar.timeText(minuteOfDay: endMinute))"
    }

    /// カレンダーのマスに出す短い表記。
    public var shortLabel: String {
        String(name.prefix(3))
    }

    /// 名前が 1〜12 文字かどうか。
    public var hasValidName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...Self.nameLengthLimit).contains(trimmed.count)
    }
}

/// 並び順・アーカイブ状態を持つシフトテンプレート。
public struct ShiftTemplate: Identifiable, Codable, Hashable, Sendable {
    /// 未アーカイブのテンプレートの上限。
    public static let activeLimit = 12

    public var id: UUID
    public var definition: ShiftDefinition
    public var sortOrder: Int
    public var isArchived: Bool

    public init(id: UUID = UUID(), definition: ShiftDefinition, sortOrder: Int, isArchived: Bool = false) {
        self.id = id
        self.definition = definition
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }

    /// 初回起動時に用意するテンプレート。
    public static var defaults: [ShiftTemplate] {
        [
            ShiftDefinition(name: "早番", kind: .work, startMinute: 7 * 60, endMinute: 16 * 60, breakMinutes: 60, color: .blue),
            ShiftDefinition(name: "日勤", kind: .work, startMinute: 9 * 60, endMinute: 18 * 60, breakMinutes: 60, color: .green),
            ShiftDefinition(name: "遅番", kind: .work, startMinute: 13 * 60, endMinute: 22 * 60, breakMinutes: 60, color: .orange),
            ShiftDefinition(
                name: "夜勤",
                kind: .work,
                startMinute: 22 * 60,
                endMinute: 7 * 60,
                crossesMidnight: true,
                breakMinutes: 60,
                color: .purple
            ),
            ShiftDefinition(name: "休み", kind: .rest, color: .gray)
        ]
        .enumerated()
        .map { ShiftTemplate(definition: $1, sortOrder: $0) }
    }
}

/// 1 日分のシフト。テンプレートを後から変えても内容が変わらないよう、定義を複製して持つ。
public struct ShiftAssignment: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// `yyyy-MM-dd`。1 日 1 件。
    public var dayKey: String
    /// 参照元テンプレート。削除・アーカイブ後も履歴は残る。
    public var templateID: UUID?
    /// 登録時点のテンプレート内容のスナップショット。
    public var definition: ShiftDefinition
    /// 端末内のみのメモ。共有画像や通知には出さない。
    public var note: String

    public static let noteLengthLimit = 100

    public init(
        id: UUID = UUID(),
        dayKey: String,
        templateID: UUID?,
        definition: ShiftDefinition,
        note: String = ""
    ) {
        self.id = id
        self.dayKey = dayKey
        self.templateID = templateID
        self.definition = definition
        self.note = String(note.prefix(Self.noteLengthLimit))
    }
}
