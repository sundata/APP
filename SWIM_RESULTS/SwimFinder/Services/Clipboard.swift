import UIKit

/// 検索語をクリップボードへコピーする。コピーするのはユーザーが入力した検索語のみ。
@MainActor
protocol ClipboardWriting: AnyObject {
    func copy(_ text: String)
}

@MainActor
final class SystemClipboard: ClipboardWriting {
    func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}

/// UI テスト用。システムのクリップボードを汚さない。
@MainActor
final class RecordingClipboard: ClipboardWriting {
    private(set) var lastCopied: String?
    func copy(_ text: String) { lastCopied = text }
}
