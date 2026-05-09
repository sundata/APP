import UIKit
import Photos

// MARK: - エクスポートオプション

struct ExportOptions: Equatable {
    /// エクスポートフォーマット
    var format: ExportFormat = .jpeg
    /// JPEG圧縮品質 (0.0~1.0)
    var jpegQuality: Double = 0.95
    /// 印刷レイアウトタイプ
    var layout: PrintLayout = .single
    /// 写真ライブラリに保存するか
    var saveToLibrary: Bool = true

    enum ExportFormat: String, CaseIterable, Identifiable {
        case jpeg = "JPEG"
        case png  = "PNG（透明対応）"
        var id: String { rawValue }
    }

    enum PrintLayout: String, CaseIterable, Identifiable {
        case single      = "1枚（そのまま）"
        case print2x2    = "2×2 コマ（A4用）"
        case print2x3    = "2×3 コマ（L判）"
        case print4x4    = "4×4 コマ（A4高密度）"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .single:   return "photo"
            case .print2x2: return "square.grid.2x2"
            case .print2x3: return "rectangle.grid.2x2"
            case .print4x4: return "square.grid.4x3.fill"
            }
        }

        var description: String {
            switch self {
            case .single:   return "最高画質で1枚保存"
            case .print2x2: return "A4用紙に4枚並べて印刷"
            case .print2x3: return "L判用紙（89×127mm）に6枚"
            case .print4x4: return "A4用紙に16枚（コスト節約）"
            }
        }
    }
}

// MARK: - エクスポート結果

enum ExportResult {
    case success(UIImage)
    case failure(ExportError)
}

enum ExportError: LocalizedError {
    case noImage
    case permissionDenied
    case saveFailed(Error)
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .noImage:           return "書き出す画像がありません"
        case .permissionDenied:  return "フォトライブラリへのアクセスが拒否されています。設定から許可してください"
        case .saveFailed(let e): return "保存に失敗しました: \(e.localizedDescription)"
        case .renderFailed:      return "画像の生成に失敗しました"
        }
    }
}

// MARK: - ExportService

class ExportService {

    private let imageService = ImageService()

    // MARK: - メイン書き出し処理

    /// 最終画像を生成して保存するメインフロー
    func export(
        image: UIImage,
        size: IDPhotoSize,
        options: ExportOptions
    ) async -> ExportResult {
        // 1. サイズにリサイズ
        let targetSize = CGSize(width: size.widthPx, height: size.heightPx)
        let resized = imageService.resizeImage(image, to: targetSize)

        // 2. レイアウト生成
        guard let layoutImage = renderLayout(resized, size: size, layout: options.layout) else {
            return .failure(.renderFailed)
        }

        // 3. フォトライブラリへ保存
        if options.saveToLibrary {
            let permissionResult = await requestPhotoLibraryPermission()
            guard permissionResult else {
                return .failure(.permissionDenied)
            }
            let saveResult = await saveToPhotoLibrary(layoutImage, format: options.format, quality: options.jpegQuality)
            if case .failure(let e) = saveResult {
                return .failure(e)
            }
        }

        return .success(layoutImage)
    }

    // MARK: - レイアウトレンダリング

    func renderLayout(_ photo: UIImage, size: IDPhotoSize, layout: ExportOptions.PrintLayout) -> UIImage? {
        switch layout {
        case .single:
            return photo
        case .print2x2:
            return renderGrid(photo: photo, photoSize: size, cols: 2, rows: 2,
                              canvasWidthMM: 210, canvasHeightMM: 297, dpi: size.dpi)
        case .print2x3:
            return renderGrid(photo: photo, photoSize: size, cols: 2, rows: 3,
                              canvasWidthMM: 89, canvasHeightMM: 127, dpi: size.dpi)
        case .print4x4:
            return renderGrid(photo: photo, photoSize: size, cols: 4, rows: 4,
                              canvasWidthMM: 210, canvasHeightMM: 297, dpi: size.dpi)
        }
    }

    // MARK: - グリッドレンダリング

    private func renderGrid(
        photo: UIImage,
        photoSize: IDPhotoSize,
        cols: Int,
        rows: Int,
        canvasWidthMM: Double,
        canvasHeightMM: Double,
        dpi: Int
    ) -> UIImage? {
        let canvasW = Int(canvasWidthMM  / 25.4 * Double(dpi))
        let canvasH = Int(canvasHeightMM / 25.4 * Double(dpi))
        let photoW  = photoSize.widthPx
        let photoH  = photoSize.heightPx

        // 余白（3mm）
        let margin  = Int(3.0 / 25.4 * Double(dpi))
        // セル間スペース（2mm）
        let spacing = Int(2.0 / 25.4 * Double(dpi))

        // 実際に並べられるコマ数を再計算
        let usableCols = min(cols, max(1, (canvasW - 2 * margin + spacing) / (photoW + spacing)))
        let usableRows = min(rows, max(1, (canvasH - 2 * margin + spacing) / (photoH + spacing)))

        // 配置開始座標（センタリング）
        let totalW = usableCols * photoW + (usableCols - 1) * spacing
        let totalH = usableRows * photoH + (usableRows - 1) * spacing
        let startX = (canvasW - totalW) / 2
        let startY = (canvasH - totalH) / 2

        let canvasSize = CGSize(width: canvasW, height: canvasH)
        let resized = imageService.resizeImage(photo, to: CGSize(width: photoW, height: photoH))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { ctx in
            // 白背景
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))

            // ガイド線（薄いグレー点線）
            let guidePath = UIBezierPath()
            guidePath.setLineDash([4, 4], count: 2, phase: 0)
            UIColor(white: 0.75, alpha: 1).setStroke()
            guidePath.lineWidth = 0.5

            for row in 0..<usableRows {
                for col in 0..<usableCols {
                    let x = startX + col * (photoW + spacing)
                    let y = startY + row * (photoH + spacing)
                    let rect = CGRect(x: x, y: y, width: photoW, height: photoH)
                    resized.draw(in: rect)

                    // コーナーガイド
                    let len: CGFloat = 8
                    let path = UIBezierPath()
                    // top-left
                    path.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y) + len))
                    path.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
                    path.addLine(to: CGPoint(x: CGFloat(x) + len, y: CGFloat(y)))
                    // top-right
                    path.move(to: CGPoint(x: CGFloat(x + photoW) - len, y: CGFloat(y)))
                    path.addLine(to: CGPoint(x: CGFloat(x + photoW), y: CGFloat(y)))
                    path.addLine(to: CGPoint(x: CGFloat(x + photoW), y: CGFloat(y) + len))
                    // bottom-left
                    path.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y + photoH) - len))
                    path.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y + photoH)))
                    path.addLine(to: CGPoint(x: CGFloat(x) + len, y: CGFloat(y + photoH)))
                    // bottom-right
                    path.move(to: CGPoint(x: CGFloat(x + photoW) - len, y: CGFloat(y + photoH)))
                    path.addLine(to: CGPoint(x: CGFloat(x + photoW), y: CGFloat(y + photoH)))
                    path.addLine(to: CGPoint(x: CGFloat(x + photoW), y: CGFloat(y + photoH) - len))

                    UIColor(white: 0.6, alpha: 1).setStroke()
                    path.lineWidth = 1.0
                    path.stroke()
                }
            }
        }
    }

    // MARK: - 写真ライブラリ保存

    private func saveToPhotoLibrary(_ image: UIImage, format: ExportOptions.ExportFormat, quality: Double) async -> ExportResult {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                _ = request
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: .success(image))
                } else {
                    let err = error ?? NSError(domain: "ExportService", code: -1)
                    continuation.resume(returning: .failure(.saveFailed(err)))
                }
            }
        }
    }

    // MARK: - 権限チェック

    func requestPhotoLibraryPermission() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let result = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return result == .authorized || result == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - 画像データ生成（共有用）

    func imageData(for image: UIImage, format: ExportOptions.ExportFormat, quality: Double) -> Data? {
        switch format {
        case .jpeg: return image.jpegData(compressionQuality: quality)
        case .png:  return image.pngData()
        }
    }
}
