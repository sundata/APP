import Foundation

/// 入力中の検索を一定時間待ってから 1 回だけ実行する。新しい入力が来たら前の待機はキャンセルする。
public actor SearchDebouncer {
    public let delay: Duration
    private var pending: Task<Void, Never>?
    private(set) public var scheduledCount = 0
    private(set) public var firedCount = 0

    public init(delay: Duration = .milliseconds(400)) {
        self.delay = delay
    }

    /// `operation` を `delay` 後に実行する。待機中に再度呼ばれた場合、前の操作は実行されない。
    public func schedule(_ operation: @escaping @Sendable () async -> Void) {
        pending?.cancel()
        scheduledCount += 1
        pending = Task.detached { [delay] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self.markFired()
            await operation()
        }
    }

    /// 待機中の操作を取り消す（画面を離れたときなど）。
    public func cancel() {
        pending?.cancel()
        pending = nil
    }

    private func markFired() {
        firedCount += 1
    }
}
