import Foundation

/// プラットフォームや実行ごとに変わらない決定的なシード。
/// `Hasher` は実行ごとに値が変わるため使わない。
public struct StableSeed: Hashable, Sendable {
    public let value: UInt64

    public init(value: UInt64) {
        self.value = value
    }

    /// FNV-1a 64bit。
    public init(_ string: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(string.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        self.value = hash
    }

    /// `localDate + zodiac + weatherCategory + contentVersion` から作る主シード。
    public init(dayKey: String, zodiac: Zodiac, weather: WeatherCategory?, contentVersion: Int) {
        let weatherToken = weather?.rawValue ?? "none"
        self.init("\(dayKey)|\(zodiac.rawValue)|\(weatherToken)|v\(contentVersion)")
    }

    /// 用途ごとに独立した派生値を得る（同じシードから複数の選択をするため）。
    public func derived(_ salt: String) -> StableSeed {
        StableSeed("\(value)|\(salt)")
    }

    /// 0..<upperBound の決定的な整数。
    public func index(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(value % UInt64(upperBound))
    }

    /// range 内の決定的な整数。
    public func int(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + index(upperBound: span)
    }
}

public extension Array {
    /// 決定的な要素選択。
    func element(for seed: StableSeed) -> Element {
        self[seed.index(upperBound: count)]
    }

    /// 決定的な要素選択（インデックス指定）。負の値も安全に扱う。
    func cyclicElement(at index: Int) -> Element {
        let normalized = ((index % count) + count) % count
        return self[normalized]
    }
}
