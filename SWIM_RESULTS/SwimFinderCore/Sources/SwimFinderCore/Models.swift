import Foundation

// MARK: - クエリ

public struct PlayerQuery: Sendable, Hashable, Codable {
    /// 正規化前の入力（表示用）
    public var rawName: String
    /// 俱乐部、学校等所属团体名称。
    public var rawAffiliation: String
    /// 正規化後の名前（送信用）
    public var name: String { QueryNormalizer.normalize(rawName) }
    public var affiliation: String { QueryNormalizer.normalize(rawAffiliation) }

    public init(rawName: String = "", rawAffiliation: String = "") {
        self.rawName = rawName
        self.rawAffiliation = rawAffiliation
    }
}

public struct MeetQuery: Sendable, Hashable, Codable {
    public var rawName: String
    /// 年度（公式検索が対応している場合のみ使う）
    public var fiscalYear: Int?
    /// 都道府県を表す加盟団体コード（例：千葉 = 12）。
    public var prefectureCode: Int?
    /// 公式の開催状態コード（開催前 = 1、記録確定 = 5 など）。
    public var statusCode: Int?
    /// 水路コード（長水路 = 1、短水路 = 2）。
    public var waterwayCode: Int?
    public var name: String { QueryNormalizer.normalize(rawName) }

    public init(rawName: String, fiscalYear: Int? = nil, prefectureCode: Int? = nil, statusCode: Int? = nil, waterwayCode: Int? = nil) {
        self.rawName = rawName
        self.fiscalYear = fiscalYear
        self.prefectureCode = prefectureCode
        self.statusCode = statusCode
        self.waterwayCode = waterwayCode
    }
}

public struct ResultFilter: Sendable, Hashable, Codable {
    public var date: String?
    public var gender: String?
    public var style: String?
    public var distance: String?
    /// nil なら FinalResultPolicy に従って決勝を優先。「すべて」は `.all`
    public var roundScope: RoundScope

    public enum RoundScope: String, Sendable, Codable {
        case finalPreferred
        case all
    }

    public init(date: String? = nil, gender: String? = nil, style: String? = nil, distance: String? = nil, roundScope: RoundScope = .finalPreferred) {
        self.date = date
        self.gender = gender
        self.style = style
        self.distance = distance
        self.roundScope = roundScope
    }
}

// MARK: - 公式データのサマリー
// 値はすべて公式レスポンスの文字列をそのまま保持する。アプリ側で推測・補完しない。

public struct PlayerSummary: Sendable, Hashable, Codable, Identifiable {
    /// 公式が発行した安定 ID
    public let id: String
    /// 選手詳細 API が使用する匿名化済み ID。同じ選手の所属行では共通。
    public let athleteID: String
    public let displayName: String
    /// 同姓同名の識別に公式画面が出す情報（所属・加盟団体・学種・性別）。提供された項目のみ。
    public let affiliation: String?
    public let memberGroup: String?
    public let schoolClass: String?
    public let gender: String?

    public init(id: String, athleteID: String? = nil, displayName: String, affiliation: String? = nil, memberGroup: String? = nil, schoolClass: String? = nil, gender: String? = nil) {
        self.id = id
        self.athleteID = athleteID ?? id
        self.displayName = displayName
        self.affiliation = affiliation
        self.memberGroup = memberGroup
        self.schoolClass = schoolClass
        self.gender = gender
    }

    public var officialURL: URL? { OfficialSite.athlete(id: athleteID) }
}

public struct PlayerProfile: Sendable, Hashable, Codable {
    public let displayName: String
    public let romanName: String?
    public let maskedCode: String
    public let affiliations: [String]
    public let memberGroup: String?
    public let schoolClass: String?
    public let gender: String?
    public let updatedAt: String?

    public init(displayName: String, romanName: String? = nil, maskedCode: String, affiliations: [String], memberGroup: String? = nil, schoolClass: String? = nil, gender: String? = nil, updatedAt: String? = nil) {
        self.displayName = displayName; self.romanName = romanName; self.maskedCode = maskedCode
        self.affiliations = affiliations; self.memberGroup = memberGroup; self.schoolClass = schoolClass
        self.gender = gender; self.updatedAt = updatedAt
    }
}

public struct MeetSummary: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let name: String
    /// 公式表記のまま（例：「2026年04月04日(土) ~ 2026年04月05日(日)」）
    public let period: String?
    public let venue: String?
    public let organizer: String?
    /// 「短水路」「長水路」など
    public let course: String?
    /// 「記録確定」など公式のステータス表記
    public let status: String?

    public init(id: String, name: String, period: String? = nil, venue: String? = nil, organizer: String? = nil, course: String? = nil, status: String? = nil) {
        self.id = id
        self.name = name
        self.period = period
        self.venue = venue
        self.organizer = organizer
        self.course = course
        self.status = status
    }

    public var officialURL: URL? { OfficialSite.tournament(id: id) }
}

public struct MeetEvent: Sendable, Hashable, Codable, Identifiable {
    public let meetID: String, date: String, gender: String, style: String, distance: String, division: String
    public let genderCode: Int, styleCode: Int, distanceCode: Int, classCode: Int, divisionCode: Int
    public var id: String { "\(date)-\(genderCode)-\(styleCode)-\(distanceCode)-\(classCode)-\(divisionCode)" }
    public var title: String { "\(gender) \(distance) \(style)" }

    public init(meetID: String, date: String, genderCode: Int, gender: String, styleCode: Int, style: String, distanceCode: Int, distance: String, classCode: Int, divisionCode: Int, division: String) {
        self.meetID = meetID; self.date = date; self.genderCode = genderCode; self.gender = gender
        self.styleCode = styleCode; self.style = style; self.distanceCode = distanceCode; self.distance = distance
        self.classCode = classCode; self.divisionCode = divisionCode; self.division = division
    }
}

/// ラウンド区分。公式表記から分類するが、分類できないものは `.unknown` として原文を保持する。
public enum RaceRound: Sendable, Hashable, Codable {
    case final
    case timedFinal
    /// 公式側で「最終順位」「総合結果」と明示されたもの
    case officialFinalStanding
    case semifinal
    case preliminary
    case unknown(String)

    /// 公式ラウンド名から分類する。前方一致・部分一致で判定し、判定できなければ unknown。
    public init(officialLabel: String) {
        let label = QueryNormalizer.normalize(officialLabel)
        if label.isEmpty {
            self = .unknown(officialLabel)
        } else if label.contains("タイム決勝") {
            self = .timedFinal
        } else if label.contains("準決勝") {
            self = .semifinal
        } else if label.hasPrefix("決勝") {
            self = .final
        } else if label.contains("最終順位") || label.contains("総合結果") || label.contains("総合順位") {
            self = .officialFinalStanding
        } else if label.hasPrefix("予選") {
            self = .preliminary
        } else {
            self = .unknown(label)
        }
    }

    /// 決勝相当（最終結果として表示してよい）か。unknown は決して true にしない。
    public var isFinalStanding: Bool {
        switch self {
        case .final, .timedFinal, .officialFinalStanding: return true
        case .semifinal, .preliminary, .unknown: return false
        }
    }

    /// 決勝優先の並び順（小さいほど優先）。
    public var priority: Int {
        switch self {
        case .final: return 0
        case .timedFinal: return 1
        case .officialFinalStanding: return 2
        case .semifinal: return 10
        case .preliminary: return 11
        case .unknown: return 99
        }
    }
}

public struct SwimResult: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let meetID: String
    public let meetName: String
    /// 公式レスポンスの記録日。選手成績の時系列表示に使用する。
    public let resultDate: String?
    public let playerID: String?
    public let playerName: String
    public let affiliation: String?
    public let eventName: String
    public let distance: String
    public let style: String
    public let gender: String?
    /// 公式のラウンド表記（原文）
    public let roundLabel: String
    /// 順位（公式表記のまま。失格・棄権は "-" や空になることがある）
    public let rank: String?
    /// 記録（公式表記のまま。秒への変換は補助値）
    public let time: String
    /// 備考（DSQ/DNS 等の公式表記）
    public let remark: String?
    /// 結果ページの公式 URL
    public let officialURL: URL?

    public init(id: String, meetID: String, meetName: String, resultDate: String? = nil, playerID: String?, playerName: String, affiliation: String?, eventName: String, distance: String, style: String, gender: String?, roundLabel: String, rank: String?, time: String, remark: String?, officialURL: URL?) {
        self.id = id
        self.meetID = meetID
        self.meetName = meetName
        self.resultDate = resultDate
        self.playerID = playerID
        self.playerName = playerName
        self.affiliation = affiliation
        self.eventName = eventName
        self.distance = distance
        self.style = style
        self.gender = gender
        self.roundLabel = roundLabel
        self.rank = rank
        self.time = time
        self.remark = remark
        self.officialURL = officialURL
    }

    public var round: RaceRound { RaceRound(officialLabel: roundLabel) }

    /// 記録文字列を秒に変換する補助値。"51.79" / "1:02.34" / "0:00.09" に対応。変換できなければ nil。
    public var seconds: Double? {
        SwimTime.seconds(from: time)
    }
}

public enum SwimTime {
    public static func seconds(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= 3, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        var total = 0.0
        for part in parts {
            guard let value = Double(part), value >= 0 else { return nil }
            total = total * 60 + value
        }
        return total
    }
}
