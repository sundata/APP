import UIKit
import SwiftUI

// MARK: - UIImage Extensions

extension UIImage {

    /// 安全にリサイズ
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }

    /// アスペクト比を保持しながら指定幅にリサイズ
    func resizedToWidth(_ targetWidth: CGFloat) -> UIImage {
        let ratio = targetWidth / size.width
        let targetHeight = size.height * ratio
        return resized(to: CGSize(width: targetWidth, height: targetHeight))
    }

    /// 回転補正（Exif orientation fix）
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? self
    }

    /// 正方形にクロップ（中央）
    func squareCropped() -> UIImage {
        let minSide = min(size.width, size.height)
        let x = (size.width - minSide) / 2
        let y = (size.height - minSide) / 2
        let cropRect = CGRect(x: x, y: y, width: minSide, height: minSide)
        guard let cgImage = cgImage?.cropping(to: cropRect.scaled(by: scale)) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }

    /// サムネイル生成
    func thumbnail(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        resized(to: size)
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    func scaled(by scale: CGFloat) -> CGRect {
        CGRect(
            x: origin.x * scale,
            y: origin.y * scale,
            width: size.width * scale,
            height: size.height * scale
        )
    }
}
