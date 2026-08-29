import Foundation
import SwiftData
import KoyomiCore

/// SwiftData への入口。View から直接 ModelContext を触らないための層。
@MainActor
final class KoyomiStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 設定

    func preferences() -> UserPreferencesRecord {
        let descriptor = FetchDescriptor<UserPreferencesRecord>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserPreferencesRecord()
        context.insert(created)
        save()
        return created
    }

    func save() {
        try? context.save()
    }

    // MARK: - 占い履歴

    func record(dayKey: String) -> FortuneRecord? {
        var descriptor = FetchDescriptor<FortuneRecord>(predicate: #Predicate { $0.dayKey == dayKey })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// その日の結果を保存する。すでに保存済みなら内容は変えず、天気だけ更新する。
    /// これにより、引っぱって更新しても当日の占いが変わらない。
    @discardableResult
    func persist(fortune: DailyFortune, weather: WeatherSnapshot?, cityName: String) -> FortuneRecord {
        let encoder = JSONEncoder()
        if let existing = record(dayKey: fortune.date) {
            if let weather, let data = try? encoder.encode(weather) {
                existing.weatherData = data
                existing.cityName = weather.cityName
            }
            save()
            return existing
        }

        let record = FortuneRecord(
            dayKey: fortune.date,
            zodiacRawValue: fortune.zodiac.rawValue,
            fortuneData: (try? encoder.encode(fortune)) ?? Data(),
            weatherData: weather.flatMap { try? encoder.encode($0) },
            cityName: cityName
        )
        context.insert(record)
        save()
        return record
    }

    func allRecords() -> [FortuneRecord] {
        let descriptor = FetchDescriptor<FortuneRecord>(sortBy: [SortDescriptor(\.dayKey, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func favorites() -> [FortuneRecord] {
        allRecords().filter(\.isFavorite)
    }

    func toggleFavorite(dayKey: String) {
        guard let record = record(dayKey: dayKey) else { return }
        record.isFavorite.toggle()
        save()
    }

    /// 連続して結果を見た日数。途切れても負の表現はしない（数字だけを扱う）。
    func currentStreak(today: Date, calendar: Calendar) -> Int {
        let keys = Set(allRecords().map(\.dayKey))
        var streak = 0
        var cursor = today
        while keys.contains(KoyomiCalendar.dayKey(for: cursor, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: - データ削除

    /// 設定画面の「すべてのデータを削除」。端末内のデータを完全に消す。
    func deleteAllData() {
        for record in allRecords() {
            context.delete(record)
        }
        let descriptor = FetchDescriptor<UserPreferencesRecord>()
        for preferences in (try? context.fetch(descriptor)) ?? [] {
            context.delete(preferences)
        }
        save()
    }
}
