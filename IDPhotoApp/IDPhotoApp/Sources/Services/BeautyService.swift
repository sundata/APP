import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 美肌・画質補正サービス（Core Image使用）
class BeautyService {

    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - 美肌・各種補正を適用する
    func applyBeauty(to image: UIImage, parameters: BeautyParameters) -> UIImage {
        guard parameters.hasAnyAdjustment else { return image }
        guard let cgImage = image.cgImage else { return image }
        var ciImage = CIImage(cgImage: cgImage)

        // 1. 明るさ・コントラスト・彩度
        if parameters.brightness != 0 || parameters.contrast != 0 || parameters.saturation != 0 {
            let colorControls = CIFilter.colorControls()
            colorControls.inputImage = ciImage
            colorControls.brightness = Float(parameters.brightness * 0.3)
            colorControls.contrast   = Float(1.0 + parameters.contrast * 0.5)
            colorControls.saturation = Float(1.0 + parameters.saturation * 0.5)
            if let output = colorControls.outputImage { ciImage = output }
        }

        // 2. 色温度（warmth）
        if parameters.warmth != 0 {
            let tempFilter = CIFilter.temperatureAndTint()
            tempFilter.inputImage = ciImage
            let targetTemp: CGFloat = 6500 + CGFloat(parameters.warmth) * 2500
            tempFilter.neutral = CIVector(x: targetTemp, y: 0)
            if let output = tempFilter.outputImage { ciImage = output }
        }

        // 3. シャープネス
        if parameters.sharpness > 0 {
            let sharpen = CIFilter.unsharpMask()
            sharpen.inputImage = ciImage
            sharpen.radius    = Float(parameters.sharpness * 2.5)
            sharpen.intensity = Float(parameters.sharpness * 0.8)
            if let output = sharpen.outputImage { ciImage = output }
        }

        // 4. ハイライト・シャドウ調整（トーンカーブ近似）
        if parameters.highlights != 0 || parameters.shadows != 0 {
            ciImage = applyHighlightShadow(to: ciImage,
                                           highlights: parameters.highlights,
                                           shadows: parameters.shadows)
        }

        // 5. フェード（白フォグ効果）
        if parameters.fade > 0 {
            let whiteColor = CIImage(color: CIColor.white)
                .cropped(to: ciImage.extent)
            let blend = CIFilter.sourceOverCompositing()
            blend.inputImage = whiteColor.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(parameters.fade * 0.35))
            ])
            blend.backgroundImage = ciImage
            if let output = blend.outputImage { ciImage = output }
        }

        // 6. 肌補正（ガウスブラー + 合成によるスムージング）
        if parameters.skinSmoothing > 0 {
            ciImage = applySkinSmoothing(to: ciImage, intensity: parameters.skinSmoothing)
        }

        // CIImageをUIImageに変換
        guard let outputCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return image
        }
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - 肌補正（ソフトスムージング）
    private func applySkinSmoothing(to image: CIImage, intensity: Double) -> CIImage {
        // ガウスブラーで滑らかにする
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image
        blur.radius     = Float(intensity * 4.0)
        guard let blurred = blur.outputImage?.cropped(to: image.extent) else { return image }

        // 元画像のエッジを検出してテクスチャ部分を保持
        let edges = CIFilter(name: "CIEdges")
        edges?.setValue(image, forKey: kCIInputImageKey)
        edges?.setValue(intensity * 3.0, forKey: kCIInputIntensityKey)
        let edgeMask = edges?.outputImage?.cropped(to: image.extent)

        // エッジを反転してスキンマスクとして使用
        var skinMask = edgeMask?.applyingFilter("CIColorInvert") ?? image
        skinMask = skinMask.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0
        ])

        // スキン領域にのみブラーを適用
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage      = blurred
        blendFilter.backgroundImage = image
        blendFilter.maskImage       = skinMask.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: Float(-intensity * 0.2),
            kCIInputContrastKey:   Float(1.5)
        ])
        return blendFilter.outputImage ?? blurred
    }

    // MARK: - ハイライト・シャドウ調整
    private func applyHighlightShadow(to image: CIImage, highlights: Double, shadows: Double) -> CIImage {
        // ハイライト: トーンカーブの上部を調整
        // シャドウ: トーンカーブの下部を調整
        // CIHighlightShadowAdjust フィルタを使用
        let filter = CIFilter(name: "CIHighlightShadowAdjust")
        filter?.setValue(image, forKey: kCIInputImageKey)
        // highlightAmount: 0.0 (暗くする) ～ 1.0 (変更なし)  →  1.0 + highlights*(-0.5) で圧縮
        filter?.setValue(Float(1.0 + highlights * (-0.5)), forKey: "inputHighlightAmount")
        // shadowAmount: 0.0 (暗いまま) ～ 1.0 (持ち上げる)
        filter?.setValue(Float(max(0, min(1, 0.5 + shadows * 0.5))), forKey: "inputShadowAmount")
        return filter?.outputImage?.cropped(to: image.extent) ?? image
    }

    // MARK: - フィルタープリセット（美肌プリセット）
    func applyPreset(_ preset: BeautyPreset, to image: UIImage) -> UIImage {
        return applyBeauty(to: image, parameters: preset.parameters)
    }
}

// MARK: - 美肌プリセット
enum BeautyPreset: String, CaseIterable {
    case none       = "なし"
    case natural    = "ナチュラル"
    case soft       = "ソフト"
    case bright     = "明るい"
    case formal     = "フォーマル"
    case vivid      = "ビビッド"

    var icon: String {
        switch self {
        case .none:    return "circle.slash"
        case .natural: return "leaf.fill"
        case .soft:    return "cloud.fill"
        case .bright:  return "sun.max.fill"
        case .formal:  return "briefcase.fill"
        case .vivid:   return "paintpalette.fill"
        }
    }

    var parameters: BeautyParameters {
        switch self {
        case .none:
            return BeautyParameters()
        case .natural:
            var p = BeautyParameters()
            p.skinSmoothing = 0.25
            p.brightness    = 0.08
            p.saturation    = 0.08
            p.warmth        = 0.1
            return p
        case .soft:
            var p = BeautyParameters()
            p.skinSmoothing = 0.45
            p.brightness    = 0.12
            p.contrast      = -0.08
            p.warmth        = 0.25
            p.fade          = 0.1
            return p
        case .bright:
            var p = BeautyParameters()
            p.brightness    = 0.22
            p.contrast      = 0.12
            p.saturation    = 0.15
            p.sharpness     = 0.2
            p.highlights    = 0.1
            return p
        case .formal:
            var p = BeautyParameters()
            p.contrast      = 0.18
            p.sharpness     = 0.3
            p.saturation    = -0.12
            p.shadows       = 0.1
            return p
        case .vivid:
            var p = BeautyParameters()
            p.saturation    = 0.35
            p.contrast      = 0.2
            p.sharpness     = 0.25
            p.brightness    = 0.05
            return p
        }
    }
}
