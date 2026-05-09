import Foundation
import CoreGraphics

// MARK: - 証明写真サイズモデル（日本標準）

struct IDPhotoSize: Identifiable, Hashable {
    let id: String
    let name: String           // 表示名
    let widthMM: Double        // 幅（mm）
    let heightMM: Double       // 高さ（mm）
    let category: SizeCategory // カテゴリ
    let description: String    // 用途説明
    let dpi: Int               // 解像度
    let isPro: Bool           // 有料版のみ（免费版では制限）

    // ピクセル数計算（300 DPI基準）
    var widthPx: Int { Int(widthMM / 25.4 * Double(dpi)) }
    var heightPx: Int { Int(heightMM / 25.4 * Double(dpi)) }

    var aspectRatio: CGFloat { CGFloat(widthMM / heightMM) }

    enum SizeCategory: String, CaseIterable {
        case passport    = "パスポート・ビザ"
        case license     = "運転免許・資格"
        case mynumber    = "マイナンバー"
        case employment  = "就職・履歴書"
        case other       = "その他"
    }
}

// MARK: - 日本標準証明写真サイズ定義

extension IDPhotoSize {
    static let allSizes: [IDPhotoSize] = [
        // ── パスポート・ビザ ──
        IDPhotoSize(id: "passport_jp",    name: "パスポート",        widthMM: 35, heightMM: 45, category: .passport,   description: "旅券申請用（35×45mm）",             dpi: 300, isPro: false),
        IDPhotoSize(id: "visa_eu",        name: "欧州ビザ",           widthMM: 35, heightMM: 45, category: .passport,   description: "ヨーロッパビザ用（35×45mm）",       dpi: 300, isPro: false),
        IDPhotoSize(id: "visa_us",        name: "米国ビザ",           widthMM: 51, heightMM: 51, category: .passport,   description: "アメリカビザ用（51×51mm）",         dpi: 300, isPro: false),
        IDPhotoSize(id: "visa_cn",        name: "中国ビザ",           widthMM: 33, heightMM: 48, category: .passport,   description: "中国ビザ用（33×48mm）",             dpi: 300, isPro: false),
        IDPhotoSize(id: "visa_kr",        name: "韓国ビザ",           widthMM: 35, heightMM: 45, category: .passport,   description: "韓国ビザ用（35×45mm）",             dpi: 300, isPro: false),
        IDPhotoSize(id: "visa_uk",        name: "英国ビザ",           widthMM: 35, heightMM: 45, category: .passport,   description: "イギリスビザ用（35×45mm）",         dpi: 300, isPro: false),
        IDPhotoSize(id: "visa_ca",        name: "カナダビザ",         widthMM: 35, heightMM: 45, category: .passport,   description: "カナダビザ用（35×45mm）",           dpi: 300, isPro: false),
        IDPhotoSize(id: "visa_au",        name: "澳洲ビザ",           widthMM: 35, heightMM: 45, category: .passport,   description: "オーストラリアビザ用（35×45mm）",   dpi: 300, isPro: false),

        // ── 運転免許・資格 ──
        IDPhotoSize(id: "license_jp",     name: "運転免許証",        widthMM: 24, heightMM: 30, category: .license,    description: "運転免許更新用（24×30mm）",         dpi: 300, isPro: false),
        IDPhotoSize(id: "exam_standard",  name: "資格試験",           widthMM: 30, heightMM: 40, category: .license,    description: "資格試験申込用（30×40mm）",         dpi: 300, isPro: false),
        IDPhotoSize(id: "jlpt",           name: "JLPT・語学",        widthMM: 30, heightMM: 40, category: .license,    description: "語学検定試験用（30×40mm）",         dpi: 300, isPro: false),

        // ── マイナンバー ──
        IDPhotoSize(id: "mynumber",       name: "マイナンバー",        widthMM: 35, heightMM: 45, category: .mynumber,   description: "個人番号カード用（35×45mm）",       dpi: 300, isPro: false),
        IDPhotoSize(id: "residence",      name: "在留カード",          widthMM: 30, heightMM: 40, category: .mynumber,   description: "在留カード申請用（30×40mm）",       dpi: 300, isPro: false),

        // ── 就職・履歴書 ──
        IDPhotoSize(id: "resume_l",       name: "履歴書（大）",       widthMM: 40, heightMM: 50, category: .employment, description: "履歴書・大（40×50mm）",             dpi: 300, isPro: false),
        IDPhotoSize(id: "resume_s",       name: "履歴書（小）",       widthMM: 30, heightMM: 40, category: .employment, description: "履歴書・小（30×40mm）",             dpi: 300, isPro: false),
        IDPhotoSize(id: "employment",     name: "就職エントリー",     widthMM: 35, heightMM: 45, category: .employment, description: "企業エントリーシート用（35×45mm）", dpi: 300, isPro: false),

        // ── アメリカ規格（履歴書・申請用）──
        IDPhotoSize(id: "us_2x3",         name: "2×3インチ",           widthMM: 51, heightMM: 76,  category: .employment, description: "アメリカ履歴書・申請用（51×76mm）",  dpi: 300, isPro: false),
        IDPhotoSize(id: "us_passport",   name: "USパスポート",        widthMM: 51, heightMM: 51,  category: .passport,   description: "アメリカパスポート用（51×51mm）",  dpi: 300, isPro: false),

        // ── 届中国・台湾規格 ──
        IDPhotoSize(id: "cn_1寸",         name: "1インチ（中国）",      widthMM: 25, heightMM: 35, category: .other,      description: "中国系写真（25×35mm）",             dpi: 300, isPro: false),
        IDPhotoSize(id: "cn_2寸",         name: "2インチ（中国）",      widthMM: 35, heightMM: 53, category: .other,      description: "中国系大中写真（35×53mm）",         dpi: 300, isPro: false),

        // ── 韓国規格 ──
        IDPhotoSize(id: "kr_3x4",         name: "3×4cm（韓国）",      widthMM: 30, heightMM: 40, category: .other,      description: "韓国標準証明写真（30×40mm）",      dpi: 300, isPro: false),

        // ── ベトナム規格 ──
        IDPhotoSize(id: "vn_3x4",         name: "3×4cm（ベトナム）",  widthMM: 30, heightMM: 40, category: .other,      description: "ベトナム証明写真（30×40mm）",      dpi: 300, isPro: false),
        IDPhotoSize(id: "vn_4x6",         name: "4×6cm（ベトナム）",  widthMM: 40, heightMM: 60, category: .other,      description: "ベトナム申請用（40×60mm）",        dpi: 300, isPro: false),

        // ── タイ規格 ──
        IDPhotoSize(id: "th_3x4",         name: "3×4cm（タイ）",       widthMM: 30, heightMM: 40, category: .other,      description: "タイ証明写真（30×40mm）",           dpi: 300, isPro: false),

        // ── その他 ──
        IDPhotoSize(id: "student_id",     name: "学生証",             widthMM: 30, heightMM: 40, category: .other,      description: "学生証・社員証用（30×40mm）",      dpi: 300, isPro: false),
        IDPhotoSize(id: "insurance",     name: "健康保険証",         widthMM: 24, heightMM: 30, category: .other,      description: "健康保険証用（24×30mm）",         dpi: 300, isPro: false),
        IDPhotoSize(id: "ca_35x45",      name: "35×45mm（汎用）",     widthMM: 35, heightMM: 45, category: .other,      description: "汎用規格（35×45mm）",             dpi: 300, isPro: false),
    ]

    ///  무료로 사용 가능한 사이즈
    static var freeSizes: [IDPhotoSize] {
        allSizes.filter { !$0.isPro }
    }

    /// 人気サイズ（ 무료版에서도 사용 가능）
    static var popularSizes: [IDPhotoSize] {
        allSizes.filter { ["passport_jp", "visa_us", "visa_eu", "visa_cn",
             "license_jp", "jlpt",
             "mynumber", "resume_l", "resume_s",
             "us_2x3", "cn_1寸", "cn_2寸"].contains($0.id) }
    }
}

// MARK: - 背景色モデル

struct BackgroundColor: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let isGradient: Bool
    let gradientEndHex: String?
    /// 放射グラデーション
    var isRadialGradient: Bool = false
    /// 透明（チェッカーパターン表示用）
    var isTransparent: Bool = false

    // MARK: - 証明写真でよく使われるプリセット
    static let presets: [BackgroundColor] = [
        // 単色
        BackgroundColor(id: "white",      name: "白",         colorHex: "#FFFFFF", isGradient: false, gradientEndHex: nil),
        BackgroundColor(id: "lightBlue",  name: "水色",       colorHex: "#AAD4F5", isGradient: false, gradientEndHex: nil),
        BackgroundColor(id: "blue",       name: "青",         colorHex: "#2471C8", isGradient: false, gradientEndHex: nil),
        BackgroundColor(id: "lightGray",  name: "薄灰",       colorHex: "#D8DCE0", isGradient: false, gradientEndHex: nil),
        BackgroundColor(id: "gray",       name: "灰色",       colorHex: "#808080", isGradient: false, gradientEndHex: nil),
        BackgroundColor(id: "red",        name: "赤",         colorHex: "#D94040", isGradient: false, gradientEndHex: nil),
        BackgroundColor(id: "pink",       name: "ピンク",     colorHex: "#F5B8C4", isGradient: false, gradientEndHex: nil),
        BackgroundColor(id: "green",      name: "緑",         colorHex: "#3DAA6A", isGradient: false, gradientEndHex: nil),
        // グラデーション
        BackgroundColor(id: "gradBlue",   name: "グラデ青",   colorHex: "#D0E8FF", isGradient: true,  gradientEndHex: "#5A9FD4"),
        BackgroundColor(id: "gradGray",   name: "グラデ灰",   colorHex: "#E8E8E8", isGradient: true,  gradientEndHex: "#AAAAAA"),
        BackgroundColor(id: "gradRadial", name: "放射グラデ", colorHex: "#E8F4FF", isGradient: true,  gradientEndHex: "#8BBEE0",
                        isRadialGradient: true),
    ]

    // MARK: - カスタムカラー生成
    static func custom(hex: String, name: String = "カスタム") -> BackgroundColor {
        BackgroundColor(id: "custom_\(hex)", name: name, colorHex: hex,
                        isGradient: false, gradientEndHex: nil)
    }

    static func customGradient(startHex: String, endHex: String,
                                isRadial: Bool = false) -> BackgroundColor {
        BackgroundColor(id: "customGrad_\(startHex)_\(endHex)",
                        name: "カスタムグラデ",
                        colorHex: startHex,
                        isGradient: true,
                        gradientEndHex: endHex,
                        isRadialGradient: isRadial)
    }
}

// MARK: - 美顔調整パラメーターモデル

struct BeautyParameters: Equatable {
    var skinSmoothing: Double = 0.0   // 肌補正 0.0〜1.0
    var brightness: Double = 0.0      // 明るさ -1.0〜1.0
    var contrast: Double = 0.0        // コントラスト -1.0〜1.0
    var saturation: Double = 0.0      // 彩度 -1.0〜1.0
    var sharpness: Double = 0.0       // シャープネス 0.0〜1.0
    var warmth: Double = 0.0          // 色温度 -1.0〜1.0
    var faceSlim: Double = 0.0        // 小顔補正 0.0〜0.3
    var eyeEnhance: Double = 0.0      // 目元補正 0.0〜0.5
    var highlights: Double = 0.0      // ハイライト -1.0〜1.0
    var shadows: Double = 0.0         // シャドウ -1.0〜1.0
    var fade: Double = 0.0            // フェード 0.0〜1.0

    static let `default` = BeautyParameters()
    
    var hasAnyAdjustment: Bool {
        skinSmoothing != 0 || brightness != 0 || contrast != 0 ||
        saturation != 0 || sharpness != 0 || warmth != 0 ||
        faceSlim != 0 || eyeEnhance != 0 || highlights != 0 ||
        shadows != 0 || fade != 0
    }
}

// MARK: - 編集状態モデル

struct CropState: Equatable {
    /// 0.0 〜 1.0 で写真上でのクロップ矩形（正規化座標）
    var normalizedRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// ズーム倍率
    var scale: CGFloat = 1.0
    /// パン（表示オフセット）
    var offset: CGSize = .zero
    /// 回転角度（度数）
    var rotation: Double = 0.0
    /// 水平フリップ
    var flipHorizontal: Bool = false
}

// 旧CropRect との互換性エイリアス
typealias CropRect = CropState

struct EditState: Equatable {
    var cropState: CropState = CropState()
    var beauty: BeautyParameters = BeautyParameters()
    var selectedBackground: BackgroundColor = BackgroundColor.presets[0]
    var selectedSize: IDPhotoSize = IDPhotoSize.allSizes[0]
    var backgroundRemoved: Bool = false

    // 後方互換
    var cropRect: CropState {
        get { cropState }
        set { cropState = newValue }
    }
}
