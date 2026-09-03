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
    let resultsProvider: SwimResultsProviding
    let resultUpdateMonitor: ResultUpdateMonitor
    let membership: MembershipStore

    init(store: LocalStore, clipboard: ClipboardWriting, clock: ClockProviding, isUITesting: Bool) {
        self.store = store
        self.clipboard = clipboard
        self.clock = clock
        self.isUITesting = isUITesting
        self.browser = OfficialSiteBrowser(isUITesting: isUITesting)
        let provider: SwimResultsProviding = isUITesting
            ? FixtureSwimResultsProvider()
            : ReliableSwimResultsProvider(upstream: OfficialSwimResultsProvider())
        self.resultsProvider = provider
        self.resultUpdateMonitor = ResultUpdateMonitor(provider: provider)
        self.membership = MembershipStore(isUITesting: isUITesting, forcesFreeTier: ProcessInfo.processInfo.arguments.contains("-uiTestingFree"))
    }
}

protocol ClockProviding: Sendable {
    func now() -> Date
}

struct SystemClock: ClockProviding {
    func now() -> Date { Date() }
}
