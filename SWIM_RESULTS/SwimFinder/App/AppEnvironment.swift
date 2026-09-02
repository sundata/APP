import Foundation
import Observation
import SwimFinderCore

/// アプリ全体の依存。View には environment 経由で渡す。
@MainActor
@Observable
final class AppEnvironment {
    let store: LocalStore
    let clipboard: ClipboardWriting
    let clock: ClockProviding
    let isUITesting: Bool
    let browser: OfficialSiteBrowser
    /// Mode B のため、結果データ取得は常に無効化されている。
    let resultsProvider: SwimResultsProviding

    init(store: LocalStore, clipboard: ClipboardWriting, clock: ClockProviding, isUITesting: Bool) {
        self.store = store
        self.clipboard = clipboard
        self.clock = clock
        self.isUITesting = isUITesting
        self.browser = OfficialSiteBrowser(isUITesting: isUITesting)
        self.resultsProvider = DisabledSwimResultsProvider()
    }
}

protocol ClockProviding: Sendable {
    func now() -> Date
}

struct SystemClock: ClockProviding {
    func now() -> Date { Date() }
}
