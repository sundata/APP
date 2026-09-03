import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Results of Japan Swimming が公開ページで使用している JSON API の読み取り実装。
public struct OfficialSwimResultsProvider: SwimResultsProviding {
    private let session: URLSession
    private let baseURL: URL

    public init(session: URLSession = .shared, baseURL: URL = URL(string: "https://result.swim.or.jp/api/v1/")!) {
        self.session = session
        self.baseURL = baseURL
    }

    public func searchPlayers(query: PlayerQuery) async throws -> [PlayerSummary] {
        let name = query.name
        let affiliation = query.affiliation
        guard QueryNormalizer.isSearchable(name) || QueryNormalizer.isSearchable(affiliation) else { return [] }
        let baseItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "entry_group_name", value: affiliation),
            URLQueryItem(name: "member_group_code", value: "99"),
            URLQueryItem(name: "school_class_code", value: "99"),
            URLQueryItem(name: "gender_code", value: "99")
        ]
        let rows: [PlayerDTO] = try await getAllPages("athletes", queryItems: baseItems)
        return rows.map {
            let athleteID = Self.athleteID(from: $0.swimmerCode)
            return PlayerSummary(
                id: "\(athleteID)-\($0.entryGroup?.code ?? "none")",
                athleteID: athleteID,
                displayName: $0.swimmerName,
                affiliation: $0.entryGroup?.name,
                memberGroup: $0.entryGroup?.memberGroup?.name,
                schoolClass: $0.schoolClass.map { dto in
                    dto.schoolGrades.map { "\(dto.name) \($0)" } ?? dto.name
                },
                gender: $0.gender?.name
            )
        }
    }

    public func playerProfile(playerID: String) async throws -> PlayerProfile {
        let dto: PlayerProfileDTO = try await get("athletes/\(playerID)", queryItems: [])
        let suffix = dto.swimmerCode.suffix(3)
        return PlayerProfile(displayName: dto.swimmerName, romanName: dto.romanName,
                             maskedCode: "****\(suffix)", affiliations: dto.entryGroups.map(\.name),
                             memberGroup: dto.memberGroup?.name, schoolClass: dto.schoolClass?.name,
                             gender: dto.gender?.name, updatedAt: dto.updatedAt)
    }

    public func searchMeets(query: MeetQuery) async throws -> [MeetSummary] {
        let name = query.name
        guard QueryNormalizer.isSearchable(name) || query.fiscalYear != nil || query.prefectureCode != nil || query.statusCode != nil || query.waterwayCode != nil else { return [] }
        // 大会 API は year 必須。UI の「指定しない」は公式サイトの表示年度を使う。
        let year: Int
        if let selectedYear = query.fiscalYear {
            year = selectedYear
        } else {
            year = try await displayYear()
        }
        var items = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "year", value: String(year))
        ]
        if let code = query.prefectureCode { items.append(URLQueryItem(name: "member_group_code", value: String(code))) }
        if let code = query.statusCode { items.append(URLQueryItem(name: "game_status", value: String(code))) }
        let rows: [MeetDTO] = try await getAllPages("games", queryItems: items)
        return rows.filter {
            (query.prefectureCode == nil || $0.group?.code == query.prefectureCode) &&
            (query.statusCode == nil || $0.gameStatus?.code == query.statusCode) &&
            (query.waterwayCode == nil || $0.waterway?.code == query.waterwayCode)
        }.map {
            MeetSummary(
                id: $0.gameCode,
                name: $0.gameName,
                period: Self.period(start: $0.startDate, end: $0.endDate),
                venue: $0.pool,
                organizer: $0.group?.name,
                course: $0.waterway?.name,
                status: $0.gameStatus?.name
            )
        }
    }

    public func playerResults(playerID: String) async throws -> [SwimResult] {
        let entries: [AthleteEntryDTO] = try await get("athletes/\(playerID)/entries", queryItems: [])
        var results: [SwimResult] = []
        for entry in entries {
            for waterway in entry.waterways {
                let path = "athletes/\(playerID)/results/waterways/\(waterway.code)/swimming_styles/\(entry.swimmingStyle.code)/distances/\(entry.distance.code)/records"
                let record: AthleteRecordsDTO = try await get(path, queryItems: [URLQueryItem(name: "period_code", value: "4")])
                for year in record.result {
                    results += year.data.map { item in
                        SwimResult(id: String(item.resultID), meetID: "", meetName: item.gameName, resultDate: item.resultDate,
                                   playerID: playerID, playerName: "", affiliation: nil,
                                   eventName: "\(entry.distance.name) \(entry.swimmingStyle.name)（\(waterway.name)）",
                                   distance: entry.distance.name, style: entry.swimmingStyle.name, gender: nil,
                                   roundLabel: item.division.name, rank: nil, time: item.resultTime,
                                   remark: item.isBestRecord ? "ベスト" : nil, officialURL: nil)
                    }
                }
            }
        }
        var seen = Set<String>()
        return results.filter { seen.insert($0.id).inserted }.sorted { ($0.meetName, $0.eventName) > ($1.meetName, $1.eventName) }
    }

    public func meetResults(meetID: String, filter: ResultFilter) async throws -> [SwimResult] {
        let events = try await meetEvents(meetID: meetID).filter {
            (filter.date == nil || $0.date == filter.date) &&
            (filter.gender == nil || $0.gender == filter.gender) &&
            (filter.style == nil || $0.style == filter.style) &&
            (filter.distance == nil || $0.distance == filter.distance)
        }
        var output: [SwimResult] = []
        for event in events.prefix(20) { output += try await eventResults(event: event) }
        return output
    }

    public func meetEvents(meetID: String) async throws -> [MeetEvent] {
        let response: RaceDaysDTO = try await get("games/\(meetID)/races", queryItems: [])
        return response.data.flatMap { day in
            day.raceGenders.flatMap { raceGender in
                raceGender.heldStyles.flatMap { heldStyle in
                    heldStyle.heldDistances.flatMap { heldDistance in
                        heldDistance.classes.flatMap { raceClass in
                            raceClass.raceDivisions.map { raceDivision in
                                MeetEvent(meetID: meetID, date: day.raceDate,
                                          genderCode: raceGender.gender.code, gender: raceGender.gender.name,
                                          styleCode: heldStyle.swimmingStyle.code, style: heldStyle.swimmingStyle.name,
                                          distanceCode: heldDistance.distance.code, distance: heldDistance.distance.name,
                                          classCode: raceClass.raceClass.code,
                                          divisionCode: raceDivision.division.code, division: raceDivision.division.name)
                            }
                        }
                    }
                }
            }
        }.sorted { ($0.date, $0.title, $0.divisionCode) > ($1.date, $1.title, $1.divisionCode) }
    }

    public func eventResults(event: MeetEvent) async throws -> [SwimResult] {
        let base = "games/\(event.meetID)"
        let suffix = "genders/\(event.genderCode)/swimming_styles/\(event.styleCode)/distances/\(event.distanceCode)/classes/\(event.classCode)"
        let heats: HeatsDTO = try await get("\(base)/heats/\(suffix)", queryItems: [])
        guard let heat = heats.data.first(where: { $0.division.code == event.divisionCode })?.heats.first else { return [] }
        let response: ResultPageDTO = try await get("\(base)/results/\(suffix)/race_divisions/\(event.divisionCode)/heats/\(heat)", queryItems: [])
        return response.data.map { result in
            SwimResult(id: String(result.resultID), meetID: event.meetID, meetName: "",
                       playerID: result.swimmers?.swimmerCode, playerName: result.swimmers?.swimmerName ?? result.teamName ?? "—",
                       affiliation: result.swimmers?.entryGroup?.name,
                       eventName: event.title, distance: event.distance, style: event.style, gender: event.gender,
                       roundLabel: event.division, rank: result.ranking.map(String.init), time: result.resultTime ?? "—",
                       remark: result.recordInfo?.isEmpty == false ? result.recordInfo : nil, officialURL: nil)
        }
    }

    private func get<Value: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> Value {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw SwimResultsError.malformedResponse
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw SwimResultsError.malformedResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SwimResultsError.malformedResponse }
            if let error = SwimResultsError.from(httpStatus: http.statusCode) { throw error }
            do { return try JSONDecoder().decode(Value.self, from: data) }
            catch { throw SwimResultsError.specChangeSuspected(detail: error.localizedDescription) }
        } catch let error as SwimResultsError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet: throw SwimResultsError.offline
            case .cannotFindHost, .dnsLookupFailed: throw SwimResultsError.dnsFailure
            case .timedOut: throw SwimResultsError.timeout
            case .cancelled: throw SwimResultsError.cancelled
            default: throw SwimResultsError.offline
            }
        }
    }

    /// 公式 API の pagination metadata に従い、全ページを取得する。
    private func getAllPages<Item: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> [Item] {
        var firstItems = queryItems
        firstItems.append(URLQueryItem(name: "page", value: "1"))
        let first: Page<Item> = try await get(path, queryItems: firstItems)
        let lastPage = max(1, first.meta?.lastPage ?? 1)
        guard lastPage > 1 else { return first.data }
        var output = first.data
        for page in 2...lastPage {
            try Task.checkCancellation()
            var items = queryItems
            items.append(URLQueryItem(name: "page", value: String(page)))
            let next: Page<Item> = try await get(path, queryItems: items)
            output.append(contentsOf: next.data)
        }
        return output
    }

    private static func period(start: String?, end: String?) -> String? {
        switch (start, end) {
        case let (start?, end?) where start != end: return "\(start) – \(end)"
        case let (start?, _): return start
        case let (_, end?): return end
        default: return nil
        }
    }

    private func displayYear() async throws -> Int {
        let years: [DisplayYearDTO] = try await get("masters/display_year", queryItems: [])
        guard let text = years.first?.year, let year = Int(text) else {
            throw SwimResultsError.malformedResponse
        }
        return year
    }

    private static func athleteID(from swimmerCode: String) -> String {
        guard let code = Int(swimmerCode) else { return swimmerCode }
        return String(3 * (code + 10_000_000) + 3)
    }
}

private struct Page<Item: Decodable>: Decodable {
    let data: [Item]
    let meta: PageMetaDTO?
}
private struct PageMetaDTO: Decodable {
    let lastPage: Int
    enum CodingKeys: String, CodingKey { case lastPage = "last_page" }
}
private struct DisplayYearDTO: Decodable { let year: String }

private struct NamedDTO: Decodable {
    let code: Int?
    let name: String
}

private struct EntryGroupDTO: Decodable {
    let code: String?
    let name: String
    let memberGroup: NamedDTO?
    enum CodingKeys: String, CodingKey { case code, name; case memberGroup = "member_group" }
}

private struct SchoolClassDTO: Decodable {
    let name: String
    let schoolGrades: Int?
    enum CodingKeys: String, CodingKey { case name; case schoolGrades = "school_grades" }
}

private struct PlayerDTO: Decodable {
    let swimmerName: String
    let swimmerCode: String
    let entryGroup: EntryGroupDTO?
    let schoolClass: SchoolClassDTO?
    let gender: NamedDTO?
    enum CodingKeys: String, CodingKey {
        case swimmerName = "swimmer_name"
        case swimmerCode = "swimmer_code"
        case entryGroup = "entry_group"
        case schoolClass = "school_class"
        case gender
    }
}

private struct PlayerProfileDTO: Decodable {
    let swimmerName: String, swimmerCode: String
    let romanName: String?, updatedAt: String?
    let entryGroups: [EntryGroupDTO]
    let memberGroup: NamedDTO?, schoolClass: NamedDTO?, gender: NamedDTO?
    enum CodingKeys: String, CodingKey {
        case swimmerName = "swimmer_name"; case swimmerCode = "swimmer_code"
        case romanName = "swimmer_name_roman"; case updatedAt = "updated_at"
        case entryGroups = "entry_groups"; case memberGroup = "member_group"
        case schoolClass = "school_class"; case gender
    }
}
private struct AthleteEntryDTO: Decodable {
    let distance: CodeNameDTO, swimmingStyle: CodeNameDTO, waterways: [CodeNameDTO]
    enum CodingKeys: String, CodingKey { case distance, waterways; case swimmingStyle = "swimming_style" }
}
private struct AthleteRecordDTO: Decodable {
    let resultID: Int, resultTime: String, gameName: String, resultDate: String
    let division: CodeNameDTO; let isBestRecord: Bool
    enum CodingKeys: String, CodingKey {
        case resultID = "result_id"; case resultTime = "result_time"; case gameName = "game_name"
        case resultDate = "result_date"; case division; case isBestRecord = "is_best_record"
    }
}
private struct AthleteRecordYearDTO: Decodable { let year: Int; let data: [AthleteRecordDTO] }
private struct AthleteRecordsDTO: Decodable { let result: [AthleteRecordYearDTO] }

private struct MeetDTO: Decodable {
    let gameCode: String
    let gameName: String
    let startDate: String?
    let endDate: String?
    let pool: String?
    let group: NamedDTO?
    let waterway: NamedDTO?
    let gameStatus: NamedDTO?
    enum CodingKeys: String, CodingKey {
        case gameCode = "game_code"
        case gameName = "game_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case pool, group, waterway
        case gameStatus = "game_status"
    }
}

private struct CodeNameDTO: Decodable { let code: Int; let name: String }
private struct DivisionDTO: Decodable { let division: CodeNameDTO }
private struct RaceClassDTO: Decodable {
    let raceClass: CodeNameDTO; let raceDivisions: [DivisionDTO]
    enum CodingKeys: String, CodingKey { case raceClass = "class"; case raceDivisions = "race_divisions" }
}
private struct HeldDistanceDTO: Decodable { let distance: CodeNameDTO; let classes: [RaceClassDTO] }
private struct HeldStyleDTO: Decodable {
    let swimmingStyle: CodeNameDTO; let heldDistances: [HeldDistanceDTO]
    enum CodingKeys: String, CodingKey { case swimmingStyle = "swimming_style"; case heldDistances = "held_distances" }
}
private struct RaceGenderDTO: Decodable {
    let gender: CodeNameDTO; let heldStyles: [HeldStyleDTO]
    enum CodingKeys: String, CodingKey { case gender; case heldStyles = "held_styles" }
}
private struct RaceDayDTO: Decodable {
    let raceDate: String; let raceGenders: [RaceGenderDTO]
    enum CodingKeys: String, CodingKey { case raceDate = "race_date"; case raceGenders = "race_genders" }
}
private struct RaceDaysDTO: Decodable { let data: [RaceDayDTO] }
private struct HeatDTO: Decodable { let division: CodeNameDTO; let heats: [Int] }
private struct HeatsDTO: Decodable { let data: [HeatDTO] }
private struct RaceSwimmerDTO: Decodable {
    let swimmerName: String, swimmerCode: String; let entryGroup: EntryGroupDTO?
    enum CodingKeys: String, CodingKey { case swimmerName = "swimmer_name"; case swimmerCode = "swimmer_code"; case entryGroup = "entry_group" }
}
private struct RaceResultDTO: Decodable {
    let resultID: Int; let ranking: Int?; let swimmers: RaceSwimmerDTO?; let teamName: String?; let resultTime: String?; let recordInfo: String?
    enum CodingKeys: String, CodingKey {
        case resultID = "result_id"; case ranking, swimmers; case teamName = "team_name"; case resultTime = "result_time"; case recordInfo = "record_info"
    }
}
private struct ResultPageDTO: Decodable { let data: [RaceResultDTO] }
