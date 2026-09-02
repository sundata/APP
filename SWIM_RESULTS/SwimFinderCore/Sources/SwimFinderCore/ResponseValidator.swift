import Foundation

/// Mode A 実装時に使うレスポンス検証。
/// 「0 件」と「壊れたレスポンス／仕様変更」を厳密に区別し、後者を空配列として扱わない。
public enum ResponseValidator {
    /// 一覧レスポンスの最小契約。`items` キーが配列で存在し、各要素に必須キーがあること。
    public struct ListContract: Sendable {
        public let itemsKey: String
        public let requiredKeys: Set<String>

        public init(itemsKey: String, requiredKeys: Set<String>) {
            self.itemsKey = itemsKey
            self.requiredKeys = requiredKeys
        }
    }

    /// JSON データを検証し、要素配列（辞書）を返す。
    /// - 空配列 → 正常な 0 件として `[]` を返す
    /// - JSON でない／`itemsKey` がない／要素が辞書でない／必須キー欠落 → `specChangeSuspected` または `malformedResponse`
    public static func validateList(_ data: Data, contract: ListContract) throws -> [[String: Any]] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SwimResultsError.malformedResponse
        }
        guard let root = object as? [String: Any] else {
            throw SwimResultsError.specChangeSuspected(detail: "root is not an object")
        }
        guard root.keys.contains(contract.itemsKey) else {
            throw SwimResultsError.specChangeSuspected(detail: "missing key '\(contract.itemsKey)'")
        }
        guard let items = root[contract.itemsKey] as? [Any] else {
            throw SwimResultsError.specChangeSuspected(detail: "'\(contract.itemsKey)' is not an array")
        }
        var dictionaries: [[String: Any]] = []
        for item in items {
            guard let dict = item as? [String: Any] else {
                throw SwimResultsError.specChangeSuspected(detail: "item is not an object")
            }
            let missing = contract.requiredKeys.subtracting(dict.keys)
            guard missing.isEmpty else {
                throw SwimResultsError.specChangeSuspected(detail: "missing keys \(missing.sorted())")
            }
            dictionaries.append(dict)
        }
        return dictionaries
    }
}
