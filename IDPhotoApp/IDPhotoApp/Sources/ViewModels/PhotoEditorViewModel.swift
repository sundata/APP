import Foundation
import SwiftUI
import PhotosUI
import Combine

@MainActor
class PhotoEditorViewModel: ObservableObject {

    // MARK: - 編集対象画像
    @Published var originalImage: UIImage?
    @Published var editedImage: UIImage?
    @Published var backgroundRemovedImage: UIImage?
    @Published var finalImage: UIImage?

    // MARK: - 編集状態
    @Published var editState = EditState()
    @Published var isProcessing: Bool = false
    @Published var processingMessage: String = ""

    // MARK: - UI状態
    @Published var currentStep: EditStep = .selectPhoto
    @Published var showSizePicker: Bool = false
    @Published var showBackgroundPicker: Bool = false
    @Published var showExportSheet: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - Undo / Redo スタック
    private var undoStack: [EditState] = []
    private var redoStack: [EditState] = []
    private let maxUndoDepth = 20

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - 書き出しオプション
    @Published var exportOptions = ExportOptions()

    /// CropView の表示サイズ（cropPreview の GeometryReader から書き込む）
    var cropViewSize: CGSize = CGSize(width: 300, height: 400)

    // MARK: - サービス（遅延初期化）
    lazy var imageService = ImageService()
    private lazy var beautyService = BeautyService()
    private lazy var backgroundService = BackgroundService()
    lazy var exportService = ExportService()

    // デバウンス用
    private var editDebounceTask: Task<Void, Never>?

    // MARK: - 編集フロー
    enum EditStep: Int, CaseIterable {
        case selectPhoto = 0
        case selectSize  = 1
        case editPhoto   = 2
        case background  = 3
        case export      = 4

        var title: String {
            switch self {
            case .selectPhoto: return "写真を選ぶ"
            case .selectSize:  return "サイズ選択"
            case .editPhoto:   return "写真編集"
            case .background:  return "背景選択"
            case .export:      return "保存・出力"
            }
        }
    }

    // MARK: - 写真を設定する
    func setImage(_ image: UIImage) {
        originalImage = image
        editedImage   = image
        finalImage    = image
        undoStack.removeAll()
        redoStack.removeAll()
        if currentStep == .selectPhoto {
            currentStep = .selectSize
        }
        applyEdits()
    }

    // MARK: - サイズを選択する
    func selectSize(_ size: IDPhotoSize) {
        pushUndo()
        editState.selectedSize = size
        editState.customSize = nil  // カスタムサイズをクリア
        applyEdits()
    }

    /// カスタムサイズを選択する
    func selectCustomSize(width: Double, height: Double, name: String) {
        pushUndo()
        editState.customSize = IDPhotoSize.CustomSizeInfo(
            widthMM: width,
            heightMM: height,
            name: name
        )
        // selectedSize はダミーとして維持（aspectRatio 等で参照されるため）
        if editState.selectedSize.id != "custom" {
            editState.selectedSize = IDPhotoSize(
                id: "custom",
                name: name,
                widthMM: width,
                heightMM: height,
                category: .custom,
                description: "カスタムサイズ（\(Int(width))×\(Int(height))mm）",
                dpi: 300
            )
        }
        applyEdits()
    }

    // MARK: - 背景色を選択する
    func selectBackground(_ bg: BackgroundColor) {
        pushUndo()
        editState.selectedBackground = bg
        applyEdits()
    }

    // MARK: - カスタムカラーで背景を設定する
    func selectCustomBackground(hex: String) {
        let bg = BackgroundColor.custom(hex: hex)
        selectBackground(bg)
    }

    // MARK: - 美肌パラメータを更新する（デバウンス付き）
    func updateBeauty(_ beauty: BeautyParameters) {
        editState.beauty = beauty
        scheduleApply()
    }

    /// 操作確定時（スライダー指を離したとき）にUndoスタックへ積む
    func commitBeautyChange() {
        pushUndo()
    }

    // MARK: - クロップ状態を更新する（デバウンス付き）
    func updateCropState(_ state: CropState) {
        editState.cropState = state
        scheduleApply()
    }

    func commitCropChange() {
        pushUndo()
    }

    // 後方互換
    func updateCropRect(_ rect: CropState) {
        updateCropState(rect)
    }

    // MARK: - 回転（90度単位）
    func rotateLeft() {
        pushUndo()
        editState.cropState.rotation -= 90
        applyEdits()
    }

    func rotateRight() {
        pushUndo()
        editState.cropState.rotation += 90
        applyEdits()
    }

    func flipHorizontal() {
        pushUndo()
        editState.cropState.flipHorizontal.toggle()
        applyEdits()
    }

    func resetCrop() {
        pushUndo()
        editState.cropState = CropState()
        applyEdits()
    }

    // MARK: - 背景除去
    func removeBackground() async {
        guard let image = originalImage else { return }
        isProcessing     = true
        processingMessage = "背景を除去しています..."
        do {
            let result = try await backgroundService.removeBackground(from: image)
            backgroundRemovedImage        = result
            editState.backgroundRemoved   = true
            applyEdits()
        } catch {
            errorMessage = "背景除去に失敗しました: \(error.localizedDescription)"
            showError    = true
        }
        isProcessing = false
    }

    // MARK: - Undo / Redo
    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(editState)
        editState = prev
        applyEdits()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(editState)
        editState = next
        applyEdits()
    }

    private func pushUndo() {
        undoStack.append(editState)
        if undoStack.count > maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    // MARK: - 編集を適用する
    func applyEdits() {
        guard let source = originalImage else { return }
        Task {
            await applyEditsAsync(source: source)
        }
    }

    /// デバウンス付き適用（スライダー操作中の過剰レンダリング防止）
    private func scheduleApply() {
        editDebounceTask?.cancel()
        editDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
            guard !Task.isCancelled else { return }
            applyEdits()
        }
    }

    private func applyEditsAsync(source: UIImage) async {
        let beauty         = editState.beauty
        let bg             = editState.selectedBackground
        let bgRemoved      = editState.backgroundRemoved
        let bgRemovedImage = backgroundRemovedImage
        let cropState      = editState.cropState
        let selectedSize   = editState.selectedSize
        let viewSize       = cropViewSize

        var processed = await Task.detached(priority: .userInitiated) { [beautyService] in
            beautyService.applyBeauty(to: source, parameters: beauty)
        }.value

        // 背景合成
        if bgRemoved, let maskImg = bgRemovedImage {
            let size = CGSize(width: processed.size.width, height: processed.size.height)
            processed = backgroundService.compositeBackground(
                subject: maskImg,
                background: bg,
                size: size
            ) ?? processed
        }

        // クロップ適用してfinalImageを生成（サイズにリサイズ）
        let svc = imageService
        let finalProcessed = await Task.detached(priority: .userInitiated) {
            var img = svc.applyCropState(cropState, to: processed, viewSize: viewSize)
            img = svc.resizeImage(img, to: CGSize(width: selectedSize.widthPx,
                                                   height: selectedSize.heightPx))
            return img
        }.value

        await MainActor.run {
            self.editedImage = processed   // プレビュー用（クロップなし）
            self.finalImage  = finalProcessed  // 保存用（クロップ+リサイズ済み）
        }
    }

    // MARK: - 最終画像を生成する（保存用・クロップ適用済み）
    func generateFinalImage(viewSize: CGSize = CGSize(width: 300, height: 400)) -> UIImage? {
        guard var img = editedImage else { return nil }
        let crop = editState.cropState
        let size = editState.selectedSize

        // クロップ適用
        img = imageService.applyCropState(crop, to: img, viewSize: viewSize)
        // 目標サイズにリサイズ
        img = imageService.resizeImage(img, to: CGSize(width: size.widthPx, height: size.heightPx))
        return img
    }

    // MARK: - エラーをリセット
    func clearError() {
        errorMessage = nil
        showError    = false
    }

    // MARK: - リセット
    func reset() {
        originalImage          = nil
        editedImage            = nil
        backgroundRemovedImage = nil
        finalImage             = nil
        editState              = EditState()
        currentStep            = .selectPhoto
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
