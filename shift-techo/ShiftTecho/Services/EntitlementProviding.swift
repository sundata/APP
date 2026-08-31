import Foundation

/// 将来の Pro 版のための抽象。MVP では常に無料プランを返し、課金 UI は持たない。
protocol EntitlementProviding: Sendable {
    var isPro: Bool { get }
}

struct FreeEntitlementProvider: EntitlementProviding {
    var isPro: Bool { false }
}
