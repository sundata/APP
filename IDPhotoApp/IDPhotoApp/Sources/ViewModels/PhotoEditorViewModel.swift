import Foundation
import SwiftUI
import PhotosUI
import Combine
import Vision

struct PhotoCheck: Identifiable { let id: String; let title: String; let detail: String; let passed: Bool }

@MainActor final class PhotoEditorViewModel: ObservableObject {
    @Published var originalImage: UIImage?; @Published var editedImage: UIImage?
    @Published var backgroundRemovedImage: UIImage?; @Published var finalImage: UIImage?
    @Published var editState = EditState(); @Published var isProcessing = false; @Published var processingMessage = ""
    @Published var currentStep: EditStep = .selectPhoto
    @Published var showSizePicker = false; @Published var showBackgroundPicker = false; @Published var showExportSheet = false
    @Published var errorMessage: String?; @Published var showError = false; @Published var exportOptions = ExportOptions()
    @Published var photoChecks: [PhotoCheck] = []; @Published var isCheckingPhoto = false; @Published var isRendering = false
    @Published var isProjectSaved = false; @Published var projectSaveMessage: String?
    private var originalCutoutImage: UIImage?; private var undoStack: [EditState] = []; private var redoStack: [EditState] = []
    private var beautySnapshot: EditState?; private var editTask: Task<Void, Never>?; private var saveTask: Task<Void, Never>?
    private var renderRevision = 0; private var checkRevision = 0; private(set) var currentProjectID: UUID?
    var canUndo: Bool { !undoStack.isEmpty }; var canRedo: Bool { !redoStack.isEmpty }; var cropViewSize = CGSize(width: 300, height: 400)
    lazy var imageService = ImageService(); private lazy var beautyService = BeautyService(); private lazy var backgroundService = BackgroundService(); lazy var exportService = ExportService()

    enum EditStep: Int, CaseIterable { case selectPhoto, selectSize, editPhoto, background, export
        var title: String { ["写真を選ぶ", "サイズ選択", "写真編集", "背景選択", "保存・出力"][rawValue] } }

    func setImage(_ image: UIImage) { currentProjectID = UUID(); originalImage = image; editedImage = image; finalImage = image; undoStack = []; redoStack = []; if currentStep == .selectPhoto { currentStep = .selectSize }; applyEdits() }
    func selectSize(_ size: IDPhotoSize) { pushUndo(); editState.selectedSize = size; editState.customSize = nil; applyEdits() }
    func selectCustomSize(width: Double, height: Double, name: String) { pushUndo(); editState.customSize = .init(widthMM: width, heightMM: height, name: name); editState.selectedSize = IDPhotoSize(id: "custom", name: name, widthMM: width, heightMM: height, category: .custom, description: "カスタムサイズ", dpi: 300); applyEdits() }
    func selectBackground(_ bg: BackgroundColor) { pushUndo(); editState.selectedBackground = bg; applyEdits() }
    func selectCustomBackground(hex: String) { selectBackground(.custom(hex: hex)) }
    func updateBeauty(_ beauty: BeautyParameters) { if beautySnapshot == nil { beautySnapshot = editState }; editState.beauty = beauty; scheduleApply() }
    func commitBeautyChange() { if let snap = beautySnapshot { undoStack.append(snap); trimUndo(); redoStack = []; beautySnapshot = nil } }
    func updateCropState(_ state: CropState) { editState.cropState = state; scheduleApply() }
    func updateCropRect(_ state: CropState) { updateCropState(state) }; func commitCropChange() { pushUndo() }
    func commitCropState(_ state: CropState) { guard state != editState.cropState else { return }; pushUndo(); editState.cropState = state; applyEdits() }
    func rotateLeft() { pushUndo(); editState.cropState.rotation -= 90; applyEdits() }; func rotateRight() { pushUndo(); editState.cropState.rotation += 90; applyEdits() }
    func flipHorizontal() { pushUndo(); editState.cropState.flipHorizontal.toggle(); applyEdits() }; func resetCrop() { pushUndo(); editState.cropState = CropState(); applyEdits() }

    func removeBackground() async { guard let image = originalImage else { return }; isProcessing = true; processingMessage = "背景を除去しています..."
        do { let result = try await backgroundService.removeBackground(from: image); backgroundRemovedImage = result; originalCutoutImage = result; editState.backgroundRemoved = true; applyEdits() }
        catch { errorMessage = "背景除去に失敗しました: \(error.localizedDescription)"; showError = true }; isProcessing = false }
    func repairBackground(points: [CGPoint], radius: CGFloat, restore: Bool) { guard !points.isEmpty, let current = backgroundRemovedImage, let baseline = originalCutoutImage else { return }; backgroundRemovedImage = backgroundService.repairAlpha(current: current, originalCutout: baseline, points: points, normalizedRadius: radius, restore: restore); applyEdits() }

    func undo() { guard let value = undoStack.popLast() else { return }; redoStack.append(editState); editState = value; applyEdits() }
    func redo() { guard let value = redoStack.popLast() else { return }; undoStack.append(editState); editState = value; applyEdits() }
    private func pushUndo() { beautySnapshot = nil; undoStack.append(editState); trimUndo(); redoStack = [] }; private func trimUndo() { if undoStack.count > 20 { undoStack.removeFirst() } }

    func applyEdits() { guard let source = originalImage else { return }; renderRevision += 1; let rev = renderRevision; isRendering = true; Task { await render(source, revision: rev) } }
    private func scheduleApply() { editTask?.cancel(); editTask = Task { try? await Task.sleep(nanoseconds: 80_000_000); guard !Task.isCancelled else { return }; applyEdits() } }
    private func render(_ source: UIImage, revision: Int) async { let state = editState, cutout = backgroundRemovedImage
        var processed = await Task.detached(priority: .userInitiated) { [beautyService] in beautyService.applyBeauty(to: source, parameters: state.beauty) }.value
        if state.backgroundRemoved, let cutout { processed = backgroundService.compositeBackground(subject: cutout, background: state.selectedBackground, size: processed.size) ?? processed }
        let view = CGSize(width: cropViewSize.width, height: cropViewSize.width / state.selectedSize.aspectRatio), service = imageService
        let result = await Task.detached(priority: .userInitiated) { service.resizeImage(service.applyCropState(state.cropState, to: processed, viewSize: view), to: CGSize(width: state.selectedSize.widthPx, height: state.selectedSize.heightPx)) }.value
        guard revision == renderRevision else { return }; editedImage = processed; finalImage = result; isRendering = false; scheduleProjectSave() }
    func generateFinalImage(viewSize: CGSize = CGSize(width: 300, height: 400)) -> UIImage? { guard let editedImage else { return nil }; let view = CGSize(width: viewSize.width, height: viewSize.width / editState.selectedSize.aspectRatio); return imageService.resizeImage(imageService.applyCropState(editState.cropState, to: editedImage, viewSize: view), to: CGSize(width: editState.selectedSize.widthPx, height: editState.selectedSize.heightPx)) }

    func checkPhoto() async { checkRevision += 1; let rev = checkRevision; guard let cg = finalImage?.cgImage else { return }; isCheckingPhoto = true; let source = originalImage, size = editState.selectedSize
        let result = await Task.detached { () -> [PhotoCheck] in var list: [PhotoCheck] = []; let req = VNDetectFaceRectanglesRequest(); try? VNImageRequestHandler(cgImage: cg).perform([req]); let faces = req.results ?? []
            list.append(.init(id: "face", title: "顔の検出", detail: faces.count == 1 ? "写真内に1人の顔を検出しました" : "顔を\(faces.count)人検出。正面の写真・切り取り位置を確認してください", passed: faces.count == 1))
            if let face = faces.first, faces.count == 1 { let ok = abs(face.boundingBox.midX - 0.5) < 0.12; list.append(.init(id: "position", title: "左右のバランス", detail: ok ? "顔が写真の中央付近にあります" : "顔が左右に寄っています。写真の位置を調整してください", passed: ok)) }
            let enough = Double(source?.cgImage?.width ?? 0) >= Double(size.widthPx) && Double(source?.cgImage?.height ?? 0) >= Double(size.heightPx); list.append(.init(id: "resolution", title: "元写真の解像度", detail: enough ? "元写真は出力ピクセル数以上です" : "元写真が小さいため、拡大すると粗くなる可能性があります", passed: enough)); return list }.value
        guard rev == checkRevision else { return }; photoChecks = result; isCheckingPhoto = false }

    func restoreProject(_ p: SavedPhotoProject) -> Bool { guard let images = ProjectStore.shared.loadImages(for: p.id) else { return false }; currentProjectID = p.id; originalImage = images.original; backgroundRemovedImage = images.cutout; originalCutoutImage = images.cutout; editState.selectedSize = IDPhotoSize.allSizes.first(where: { $0.id == p.sizeID }) ?? IDPhotoSize.allSizes[0]
        if let w = p.customWidth, let h = p.customHeight { let n = p.customName ?? "カスタムサイズ"; editState.customSize = .init(widthMM: w, heightMM: h, name: n); editState.selectedSize = IDPhotoSize(id: "custom", name: n, widthMM: w, heightMM: h, category: .custom, description: "保存済みカスタムサイズ", dpi: 300) }
        editState.selectedBackground = BackgroundColor(id: p.backgroundID, name: p.backgroundName, colorHex: p.backgroundStartHex, isGradient: p.backgroundGradient, gradientEndHex: p.backgroundEndHex, isRadialGradient: p.backgroundRadial); editState.backgroundRemoved = p.backgroundRemoved && images.cutout != nil; editState.cropState = CropState(scale: p.cropScale, offset: CGSize(width: p.cropOffsetX, height: p.cropOffsetY), rotation: p.cropRotation, flipHorizontal: p.cropFlipped)
        var b = BeautyParameters(); b.skinSmoothing = p.skinSmoothing; b.brightness = p.brightness; b.contrast = p.contrast; b.saturation = p.saturation; b.sharpness = p.sharpness; b.warmth = p.warmth; b.highlights = p.highlights; b.shadows = p.shadows; b.fade = p.fade; editState.beauty = b; currentStep = .editPhoto; applyEdits(); return true }
    func saveProjectNow() { guard let id = currentProjectID, let originalImage else { return }; let s = editState
        let p = SavedPhotoProject(id: id, updatedAt: Date(), projectName: ProjectStore.shared.project(id: id)?.projectName, sizeID: s.selectedSize.id, customWidth: s.customSize?.widthMM, customHeight: s.customSize?.heightMM, customName: s.customSize?.name, backgroundID: s.selectedBackground.id, backgroundName: s.selectedBackground.name, backgroundStartHex: s.selectedBackground.colorHex, backgroundEndHex: s.selectedBackground.gradientEndHex, backgroundGradient: s.selectedBackground.isGradient, backgroundRadial: s.selectedBackground.isRadialGradient, backgroundRemoved: s.backgroundRemoved, cropScale: s.cropState.scale, cropOffsetX: s.cropState.offset.width, cropOffsetY: s.cropState.offset.height, cropRotation: s.cropState.rotation, cropFlipped: s.cropState.flipHorizontal, skinSmoothing: s.beauty.skinSmoothing, brightness: s.beauty.brightness, contrast: s.beauty.contrast, saturation: s.beauty.saturation, sharpness: s.beauty.sharpness, warmth: s.beauty.warmth, highlights: s.beauty.highlights, shadows: s.beauty.shadows, fade: s.beauty.fade)
        do { try ProjectStore.shared.save(p, original: originalImage, cutout: backgroundRemovedImage, preview: finalImage); isProjectSaved = true } catch { projectSaveMessage = "プロジェクトを端末に保存できませんでした" } }
    private func scheduleProjectSave() { guard currentProjectID != nil else { return }; isProjectSaved = false; saveTask?.cancel(); saveTask = Task { try? await Task.sleep(nanoseconds: 700_000_000); guard !Task.isCancelled else { return }; saveProjectNow() } }
    func beginNewVariant() { saveProjectNow(); currentProjectID = UUID(); isProjectSaved = false; scheduleProjectSave() }
    func clearError() { errorMessage = nil; showError = false }
    func reset() { editTask?.cancel(); saveTask?.cancel(); renderRevision += 1; originalImage = nil; editedImage = nil; backgroundRemovedImage = nil; originalCutoutImage = nil; finalImage = nil; editState = EditState(); currentStep = .selectPhoto; undoStack = []; redoStack = []; currentProjectID = nil; photoChecks = []; isProjectSaved = false }
}
