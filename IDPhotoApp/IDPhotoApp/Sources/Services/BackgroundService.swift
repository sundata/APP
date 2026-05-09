import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 背景除去・合成サービス
/// - Vision VNGeneratePersonSegmentationRequest（iOS 15+）でAI人物分割
/// - エッジ羽化処理で自然な境界を実現
/// - 単色・グラデーション・カスタムカラー・チェッカーパターン対応
class BackgroundService {

    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - AI背景除去（精細化版）
    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw BackgroundError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest { [weak self] req, error in
                guard let self else { return }
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let obs = req.results?.first as? VNPixelBufferObservation else {
                    continuation.resume(throwing: BackgroundError.segmentationFailed)
                    return
                }

                do {
                    let result = try self.applyMask(obs.pixelBuffer, to: cgImage, sourceImage: image)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            // 高品質モード
            request.qualityLevel          = .accurate
            request.outputPixelFormat     = kCVPixelFormatType_OneComponent8

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - マスク適用（エッジ羽化付き）
    private func applyMask(_ maskBuffer: CVPixelBuffer,
                           to cgImage: CGImage,
                           sourceImage: UIImage) throws -> UIImage {
        let originalCI = CIImage(cgImage: cgImage)
        var maskCI     = CIImage(cvPixelBuffer: maskBuffer)

        // マスクを元画像サイズにスケール
        let scaleX = originalCI.extent.width  / maskCI.extent.width
        let scaleY = originalCI.extent.height / maskCI.extent.height
        maskCI = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // ─ エッジ羽化（境界をぼかしてきれいに切り抜く）
        let blurred = maskCI.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 1.5
        ]).cropped(to: originalCI.extent)

        // ─ コントラスト強化でマスク境界をクリアに
        let sharpMask = blurred.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey:   1.2,
            kCIInputBrightnessKey: 0.02
        ]).cropped(to: originalCI.extent)

        // ─ ブレンド（透明背景に切り抜き）
        let blend = CIFilter.blendWithMask()
        blend.inputImage      = originalCI
        blend.maskImage       = sharpMask
        blend.backgroundImage = CIImage(color: .clear).cropped(to: originalCI.extent)

        guard let output   = blend.outputImage,
              let outputCG = ciContext.createCGImage(output, from: output.extent) else {
            throw BackgroundError.compositionFailed
        }
        return UIImage(cgImage: outputCG, scale: sourceImage.scale,
                       orientation: sourceImage.imageOrientation)
    }

    // MARK: - 背景合成（被写体 + 背景定義）
    func compositeBackground(subject: UIImage,
                             background: BackgroundOption,
                             size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // 背景を描画
            drawBackground(background, in: CGRect(origin: .zero, size: size), ctx: ctx.cgContext)
            // 被写体を合成
            subject.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 後方互換：BackgroundColor → BackgroundOption ラッパー
    func compositeBackground(subject: UIImage,
                             background: BackgroundColor,
                             size: CGSize) -> UIImage? {
        compositeBackground(subject: subject,
                            background: .preset(background),
                            size: size)
    }

    // MARK: - 背景描画コア
    private func drawBackground(_ option: BackgroundOption,
                                in rect: CGRect,
                                ctx: CGContext) {
        switch option {
        case .preset(let bg):
            if bg.isGradient, let endHex = bg.gradientEndHex {
                drawGradient(in: rect, ctx: ctx,
                             from: UIColor(hex: bg.colorHex) ?? .white,
                             to:   UIColor(hex: endHex) ?? .lightGray)
            } else {
                (UIColor(hex: bg.colorHex) ?? .white).setFill()
                ctx.fill(rect)
            }

        case .solidColor(let color):
            color.setFill()
            ctx.fill(rect)

        case .gradient(let start, let end, let isRadial):
            if isRadial {
                drawRadialGradient(in: rect, ctx: ctx, from: start, to: end)
            } else {
                drawGradient(in: rect, ctx: ctx, from: start, to: end)
            }

        case .checker:
            drawCheckerPattern(in: rect, ctx: ctx)
        }
    }

    // ─ リニアグラデーション（上→下）
    private func drawGradient(in rect: CGRect, ctx: CGContext,
                              from startColor: UIColor, to endColor: UIColor) {
        let colors = [startColor.cgColor, endColor.cgColor] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors, locations: [0, 1]
        ) else { return }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end:   CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }

    // ─ 放射グラデーション（中心→外）
    private func drawRadialGradient(in rect: CGRect, ctx: CGContext,
                                    from startColor: UIColor, to endColor: UIColor) {
        let colors = [startColor.cgColor, endColor.cgColor] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors, locations: [0, 1]
        ) else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) * 0.7
        ctx.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter:   center, endRadius:   radius,
            options: [.drawsAfterEndLocation]
        )
    }

    // ─ チェッカーパターン（透明背景表示用）
    private func drawCheckerPattern(in rect: CGRect, ctx: CGContext) {
        let tileSize: CGFloat = 12
        let light = UIColor(white: 0.88, alpha: 1)
        let dark  = UIColor(white: 0.72, alpha: 1)
        let cols  = Int(ceil(rect.width  / tileSize))
        let rows  = Int(ceil(rect.height / tileSize))
        for row in 0..<rows {
            for col in 0..<cols {
                let isLight = (row + col) % 2 == 0
                (isLight ? light : dark).setFill()
                let tile = CGRect(x: rect.minX + CGFloat(col) * tileSize,
                                  y: rect.minY + CGFloat(row) * tileSize,
                                  width: tileSize, height: tileSize)
                ctx.fill(tile)
            }
        }
    }
}

// MARK: - 背景オプション（拡張版）
enum BackgroundOption {
    case preset(BackgroundColor)
    case solidColor(UIColor)
    case gradient(UIColor, UIColor, isRadial: Bool)
    case checker   // 透明（チェッカー表示）
}

// MARK: - エラー定義
enum BackgroundError: LocalizedError {
    case invalidImage
    case segmentationFailed
    case compositionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:       return "無効な画像です"
        case .segmentationFailed: return "人物の検出に失敗しました"
        case .compositionFailed:  return "背景合成に失敗しました"
        }
    }
}
