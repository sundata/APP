import Foundation

/// 現在時刻の抽象。テストとスクリーンショットを固定するために注入する。
protocol ClockProviding: Sendable {
    var now: Date { get }
}

struct SystemClock: ClockProviding {
    var now: Date { Date() }
}

struct FixedClock: ClockProviding {
    let now: Date

    init(_ now: Date) {
        self.now = now
    }
}
