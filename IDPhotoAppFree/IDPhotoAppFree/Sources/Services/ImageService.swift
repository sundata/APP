import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 画像処理サービス（クロップ・リサイズ・書き出し・回転・フリップ）
class ImageService {

    private lazy var context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - リサイズ
    func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - アスペクト比にフィット（中央クロップ）
    func cropToAspectRatio(_ image: UIImage, aspectRatio: CGFloat) -> UIImage {
        let imageAspect = image.size.width / image.size.height
        var cropRect: CGRect

        if imageAspect > aspectRatio {
            let newW    = image.size.height * aspectRatio
            let xOffset = (image.size.width - newW) / 2
            cropRect    = CGRect(x: xOffset, y: 0, width: newW, height: image.size.height)
        } else {
            let newH    = image.size.width / aspectRatio
            // 顔は上部にあることが多いため 20% 上寄りにオフセット
            let yOffset = max(0, (image.size.height - newH) * 0.2)
            cropRect    = CGRect(x: 0, y: yOffset, width: image.size.width, height: newH)
        }

        guard let cgImage = image.cgImage else { return image }
        let scale       = image.scale
        let scaledRect  = CGRect(
            x: cropRect.origin.x    * scale,
            y: cropRect.origin.y    * scale,
            width:  cropRect.size.width  * scale,
            height: cropRect.size.height * scale
        )
        guard let cropped = cgImage.cropping(to: scaledRect) else { return image }
        return UIImage(cgImage: cropped, scale: scale, orientation: image.imageOrientation)
    }

    // MARK: - CropState を適用してクロップ画像を生成
    /// scale / offset は View 上の表示パラメータ。
    /// この関数では「ユーザーが見ている矩形」を画像座標に変換してクロップする。
    func applyCropState(_ cropState: CropState,
                        to image: UIImage,
                        viewSize: CGSize) -> UIImage {
        // --- 回転 ---
        var working = image
        if cropState.rotation != 0 {
            working = rotatedImage(working, degrees: cropState.rotation) ?? working
        }
        // --- 水平フリップ ---
        if cropState.flipHorizontal {
            working = flippedHorizontally(working) ?? working
        }
        // --- スケール + オフセット からクロップ矩形を計算 ---
        // (View内でfitしたときの実際の表示サイズ)
        let imgAspect   = working.size.width / working.size.height
        let viewAspect  = viewSize.width / viewSize.height
        let fitW: CGFloat
        let fitH: CGFloat
        if imgAspect > viewAspect {
            fitW = viewSize.width
            fitH = viewSize.width / imgAspect
        } else {
            fitH = viewSize.height
            fitW = viewSize.height * imgAspect
        }

        // 表示スケール：画像px → view points 変換係数
        let displayScale = fitW / working.size.width

        // 中心を offset だけずらした後のクロップ矩形（view座標）
        let cropViewW = fitW / cropState.scale
        let cropViewH = fitH / cropState.scale
        let originX   = (viewSize.width  - cropViewW) / 2 - cropState.offset.width  / cropState.scale
        let originY   = (viewSize.height - cropViewH) / 2 - cropState.offset.height / cropState.scale

        // 画像座標へ変換
        let imgX = max(0, originX / displayScale)
        let imgY = max(0, originY / displayScale)
        let imgW = min(working.size.width  - imgX, cropViewW / displayScale)
        let imgH = min(working.size.height - imgY, cropViewH / displayScale)

        guard imgW > 0, imgH > 0, let cgImage = working.cgImage else { return working }
        let scale       = working.scale
        let pixelRect   = CGRect(x: imgX * scale,  y: imgY * scale,
                                 width: imgW * scale, height: imgH * scale)
        guard let cropped = cgImage.cropping(to: pixelRect) else { return working }
        return UIImage(cgImage: cropped, scale: scale, orientation: working.imageOrientation)
    }

    // MARK: - 回転（任意角度、背景透明）
    func rotatedImage(_ image: UIImage, degrees: Double) -> UIImage? {
        let radians     = CGFloat(degrees) * .pi / 180
        let originalSize = image.size
        let newSize     = CGRect(origin: .zero, size: originalSize)
            .applying(CGAffineTransform(rotationAngle: radians)).size
        let renderer    = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            ctx.cgContext.rotate(by: radians)
            image.draw(at: CGPoint(x: -originalSize.width / 2, y: -originalSize.height / 2))
        }
    }

    // MARK: - 水平フリップ
    func flippedHorizontally(_ image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.translateBy(x: image.size.width, y: 0)
        ctx.scaleBy(x: -1, y: 1)
        image.draw(at: .zero)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - PNG/JPEG書き出し
    func exportAsJPEG(_ image: UIImage, quality: CGFloat = 0.95) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    func exportAsPNG(_ image: UIImage) -> Data? {
        image.pngData()
    }

    // MARK: - フォトライブラリに保存
    func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        completion(true, nil)
    }

    // MARK: - 複数枚プリント用レイアウト生成（L判: 89×127mm @ 300dpi）
    func generatePrintLayout(for image: UIImage, size: IDPhotoSize, printDPI: Int = 300) -> UIImage? {
        let lPrintW = Int(89.0 / 25.4 * Double(printDPI))
        let lPrintH = Int(127.0 / 25.4 * Double(printDPI))
        let photoW  = size.widthPx
        let photoH  = size.heightPx
        let margin  = 20
        let cols    = max(1, (lPrintW - margin) / (photoW + margin))
        let rows    = max(1, (lPrintH - margin) / (photoH + margin))

        let canvasSize = CGSize(width: lPrintW, height: lPrintH)
        let renderer   = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
            let resized = resizeImage(image, to: CGSize(width: photoW, height: photoH))
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = margin + col * (photoW + margin)
                    let y = margin + row * (photoH + margin)
                    resized.draw(in: CGRect(x: x, y: y, width: photoW, height: photoH))
                }
            }
        }
    }
}
