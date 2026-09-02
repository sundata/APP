import Foundation
import Observation
import SwiftData
import SwimFinderCore

/// 端末内の履歴・お気に入りストア。外部送信は一切行わない。
@MainActor
@Observable
final class LocalStore {
    private let context: ModelContext
    private(set) var recentSearches: [RecentSearch] = []
    private(set) var favorites: [FavoriteLink] = []
    private(set) var lastError: String?

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    // MARK: 履歴

    func recordSearch(_ item: RecentSearch) {
        guard SearchHistoryPolicy.shouldRecord(rawQuery: item.rawQuery) else { return }
        let updated = SearchHistoryPolicy.appending(item, to: recentSearches)
        replaceAllRecents(with: updated)
    }

    func deleteRecent(_ item: RecentSearch) {
        replaceAllRecents(with: recentSearches.filter { $0.id != item.id })
    }

    func clearRecents() {
        replaceAllRecents(with: [])
    }

    private func replaceAllRecents(with items: [RecentSearch]) {
        do {
            try context.delete(model: RecentSearchRecord.self)
            for item in items { context.insert(RecentSearchRecord(item)) }
            try context.save()
            recentSearches = items
            lastError = nil
        } catch {
            lastError = "履歴の保存に失敗しました。"
        }
    }

    // MARK: お気に入り

    func isFavorite(_ url: URL) -> Bool {
        favorites.contains { $0.url == url }
    }

    /// 公式 URL 以外は保存しない。既に同じ URL があれば何もしない。
    @discardableResult
    func addFavorite(title: String, url: URL) -> Bool {
        guard !isFavorite(url), let link = FavoriteLink(title: title, url: url, createdAt: Date()) else { return false }
        context.insert(FavoriteRecord(link))
        return persistFavorites()
    }

    func removeFavorite(_ link: FavoriteLink) {
        removeFavorite(url: link.url)
    }

    func removeFavorite(url: URL) {
        let target = url.absoluteString
        let descriptor = FetchDescriptor<FavoriteRecord>(predicate: #Predicate { $0.urlString == target })
        do {
            for record in try context.fetch(descriptor) { context.delete(record) }
        } catch {
            lastError = "お気に入りの削除に失敗しました。"
        }
        persistFavorites()
    }

    func clearFavorites() {
        do {
            try context.delete(model: FavoriteRecord.self)
        } catch {
            lastError = "お気に入りの削除に失敗しました。"
        }
        persistFavorites()
    }

    @discardableResult
    private func persistFavorites() -> Bool {
        do {
            try context.save()
            reload()
            lastError = nil
            return true
        } catch {
            lastError = "お気に入りの保存に失敗しました。"
            return false
        }
    }

    // MARK: 読み込み

    func reload() {
        let recentDescriptor = FetchDescriptor<RecentSearchRecord>(sortBy: [SortDescriptor(\.searchedAt, order: .reverse)])
        let favoriteDescriptor = FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            recentSearches = Array(try context.fetch(recentDescriptor).compactMap(\.item).prefix(SearchHistoryPolicy.maxCount))
            favorites = try context.fetch(favoriteDescriptor).compactMap(\.link)
        } catch {
            lastError = "保存データの読み込みに失敗しました。"
        }
    }

    // MARK: UI テスト用シード

    func seedForUITests() {
        let now = Date()
        recordSearch(RecentSearch(kind: .player, rawQuery: "架空 太郎", officialURL: OfficialSite.playerSearch, searchedAt: now.addingTimeInterval(-60)))
        recordSearch(RecentSearch(kind: .meet, rawQuery: "サンプル市民水泳大会", fiscalYear: 2026, officialURL: OfficialSite.tournamentList, searchedAt: now))
        addFavorite(title: "選手検索（公式）", url: OfficialSite.playerSearch)
    }
}
