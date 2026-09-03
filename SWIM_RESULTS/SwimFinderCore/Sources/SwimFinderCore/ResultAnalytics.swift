import Foundation

public enum CourseKind: String, Sendable, Hashable, Codable {
    case long = "長水路"
    case short = "短水路"
    case unknown = "水路不明"
}

public struct PerformanceEventKey: Sendable, Hashable, Codable {
    public let distance: String
    public let style: String
    public let gender: String?
    public let course: CourseKind

    public init(result: SwimResult) {
        distance = QueryNormalizer.normalize(result.distance)
        style = QueryNormalizer.normalize(result.style)
        gender = result.gender.map(QueryNormalizer.normalize)
        if result.eventName.contains(CourseKind.long.rawValue) { course = .long }
        else if result.eventName.contains(CourseKind.short.rawValue) { course = .short }
        else { course = .unknown }
    }
}

/// 自己ベストや成長表示に使える公式記録だけを扱う。
public enum ResultAnalytics {
    public static func isEligiblePerformance(_ result: SwimResult) -> Bool {
        guard let seconds = result.seconds, seconds > 0 else { return false }
        let remark = QueryNormalizer.normalize(result.remark ?? "").uppercased()
        let invalidMarkers = ["DSQ", "DNS", "DNF", "失格", "棄権", "途中棄権"]
        return !invalidMarkers.contains { remark.contains($0) }
    }

    public static func personalBest(in results: [SwimResult]) -> SwimResult? {
        results.filter(isEligiblePerformance).min { ($0.seconds ?? .greatestFiniteMagnitude) < ($1.seconds ?? .greatestFiniteMagnitude) }
    }

    public static func groupedPerformances(_ results: [SwimResult]) -> [PerformanceEventKey: [SwimResult]] {
        Dictionary(grouping: results.filter(isEligiblePerformance), by: PerformanceEventKey.init)
    }

    public static func chronological(_ results: [SwimResult]) -> [SwimResult] {
        results.filter(isEligiblePerformance).sorted {
            if ($0.resultDate ?? "") == ($1.resultDate ?? "") { return $0.id < $1.id }
            return ($0.resultDate ?? "") < ($1.resultDate ?? "")
        }
    }

    /// 同一種目・同一水路の直近2記録の差。負数は短縮、正数は増加。
    public static func latestDelta(in results: [SwimResult]) -> Double? {
        let values = chronological(results)
        guard values.count >= 2, let latest = values.last?.seconds, let previous = values.dropLast().last?.seconds else { return nil }
        return latest - previous
    }

    /// 直近から遡って連続でタイムを短縮した回数。
    public static func consecutiveImprovementCount(in results: [SwimResult]) -> Int {
        let values = chronological(results).compactMap(\.seconds)
        guard values.count >= 2 else { return 0 }
        var count = 0
        for index in stride(from: values.count - 1, through: 1, by: -1) {
            guard values[index] < values[index - 1] else { break }
            count += 1
        }
        return count
    }

    public static func isAnnualBest(_ result: SwimResult, among results: [SwimResult]) -> Bool {
        guard let year = result.resultDate?.prefix(4) else { return false }
        let sameYear = results.filter { $0.resultDate?.hasPrefix(year) == true }
        return personalBest(in: sameYear)?.id == result.id
    }
}
