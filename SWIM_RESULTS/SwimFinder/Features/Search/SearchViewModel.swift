import Foundation
import Observation
import SwimFinderCore

/// 選手検索・大会検索で共通の「公式サイトを開く」フロー（Mode B）。
@MainActor
@Observable
final class SearchViewModel {
    enum Kind {
        case player
        case meet
    }

    let kind: Kind
    var rawQuery = ""
    var fiscalYear: Int?
    private(set) var errorMessage: String?
    private(set) var lastGuidance: String?

    private let store: LocalStore
    private let clipboard: ClipboardWriting
    private let clock: ClockProviding
    private let browser: OfficialSiteBrowser

    init(kind: Kind, environment: AppEnvironment) {
        self.kind = kind
        self.store = environment.store
        self.clipboard = environment.clipboard
        self.clock = environment.clock
        self.browser = environment.browser
    }

    var normalizedQuery: String { QueryNormalizer.normalize(rawQuery) }
    var canSubmit: Bool { QueryNormalizer.isSearchable(rawQuery) }

    /// 選択可能な年度（公式サイトは年度単位で大会を管理している）。
    var selectableYears: [Int] {
        let current = Calendar(identifier: .gregorian).component(.year, from: clock.now())
        return Array((current - 5)...(current + 1)).reversed()
    }

    func openOfficialSite() {
        let now = clock.now()
        let result: Result<OfficialSiteLaunch.Plan, OfficialSiteLaunch.Failure>
        switch kind {
        case .player:
            result = OfficialSiteLaunch.player(PlayerQuery(rawName: rawQuery), now: now)
        case .meet:
            result = OfficialSiteLaunch.meet(MeetQuery(rawName: rawQuery, fiscalYear: fiscalYear), now: now)
        }
        switch result {
        case .failure(let failure):
            errorMessage = failure.userMessage
            lastGuidance = nil
        case .success(let plan):
            errorMessage = nil
            clipboard.copy(plan.clipboardText)
            if let item = plan.historyItem { store.recordSearch(item) }
            lastGuidance = plan.guidance
            browser.open(plan)
        }
    }

    func copyOnly() {
        guard canSubmit else {
            errorMessage = OfficialSiteLaunch.Failure.tooShort(minimum: QueryNormalizer.minimumLength).userMessage
            return
        }
        clipboard.copy(normalizedQuery)
        errorMessage = nil
        lastGuidance = "「\(normalizedQuery)」をコピーしました。"
    }

    func clearMessages() {
        errorMessage = nil
        lastGuidance = nil
    }
}
