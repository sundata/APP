import Foundation
import ShiftTechoCore

/// JSON バックアップの読み書き。ネットワークには一切送信しない。
protocol BackupProviding: Sendable {
    /// 書き出したファイルの URL を返す。共有シートに渡す。
    func write(_ document: BackupDocument) throws -> URL
    /// 読み込み。schema version と内容を検証する。
    func read(from url: URL) throws -> BackupDocument
}

struct FileBackupProvider: BackupProviding {
    private let directory: URL

    init(directory: URL = FileManager.default.temporaryDirectory) {
        self.directory = directory
    }

    func write(_ document: BackupDocument) throws -> URL {
        let data = try BackupCodec.encode(document)
        let url = directory.appendingPathComponent(BackupCodec.fileName(exportedAt: document.exportedAt))
        try data.write(to: url, options: .atomic)
        return url
    }

    func read(from url: URL) throws -> BackupDocument {
        // セキュリティスコープ付き URL（ファイルアプリ経由）でも読めるようにする。
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        return try BackupCodec.decode(data)
    }
}
