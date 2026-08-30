import SwiftUI
import UIKit

// MARK: - 写真編集メイン画面（全画面エディター）

struct PhotoEditorView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var activeSheet: EditorSheet? = nil
    @State private var beautyState: BeautyParameters = BeautyParameters()
    @State private var selectedPreset: BeautyPreset = .none
    @State private var showBeautyComparison: Bool = false

    // MARK: - 内包シート種別
    private enum EditorSheet: String, CaseIterable, Identifiable {
        case size       = "サイズ"
        case background = "背景"
        case beauty     = "自然補正"
        case crop       = "構図"
        case repair     = "境界修正"

        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            if viewModel.currentStep == .export {
                // 导出页面（含返回按钮，在 ExportView 内部实现）
                ExportView(viewModel: viewModel)
            } else {
                // 编辑页面
                ZStack {
                    // ── フルスクリーン写真 ────────────────────────────────────
                    fullScreenPhotoArea
                        .ignoresSafeArea()

                    // ── 上部オーバーレイ（半透明ナビゲーションバー）─────────
                    VStack(spacing: 0) {
                        topNavBar
                        Spacer()
                    }

                    // ── 下部ツールバー ──────────────────────────────────────
                    VStack(spacing: 0) {
                        Spacer()
                        bottomToolbar
                            .padding(.bottom, uiBottomInset)
                    }

                    // ── 処理中オーバーレイ ──────────────────────────────────
                    if viewModel.isProcessing {
                        ProcessingOverlay(message: viewModel.processingMessage)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
                .presentationDetents(sheet == .beauty ? [.medium] : [.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(sheet == .beauty)
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            beautyState = viewModel.editState.beauty
        }
    }

    // MARK: - フルスクリーン写真エリア

    private var fullScreenPhotoArea: some View {
        let targetSize  = viewModel.editState.selectedSize
        let bg          = viewModel.editState.selectedBackground
        let aspectRatio = targetSize.aspectRatio
        let rotation    = viewModel.editState.cropState.rotation

        return GeometryReader { geo in
            ZStack {
                // 深色背景
                Color(hex: "#0D1B2A")
                    .ignoresSafeArea()

                if let image = viewModel.editedImage ?? viewModel.originalImage {
                    // 背景ぼかし
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 24)
                        .opacity(0.25)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // メインプレビュー（居中显示）
                    let availableW  = geo.size.width  - 64
                    let availableH  = geo.size.height - 180
                    let displayW: CGFloat = aspectRatio >= 1
                        ? min(availableW, availableH * aspectRatio)
                        : min(availableW, availableH * aspectRatio)
                    let displayH: CGFloat = displayW / aspectRatio

                    ZStack {
                        backgroundColorView(for: bg)
                            .frame(width: displayW, height: displayH)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.5), radius: 16, y: 6)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: displayW, height: displayH)
                            .clipped()
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                            .rotationEffect(.degrees(rotation))
                    }
                    .frame(width: displayW, height: displayH)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 - 30)

                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 56))
                            .foregroundColor(.white.opacity(0.3))
                        Text("写真が選択されていません")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                // 右下：サイズバッジ
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        sizeBadge
                            .padding(16)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    @ViewBuilder
    private func backgroundColorView(for bg: BackgroundColor) -> some View {
        if bg.isGradient, let endHex = bg.gradientEndHex {
            if bg.isRadialGradient {
                RadialGradient(
                    colors: [Color(hex: bg.colorHex), Color(hex: endHex)],
                    center: .center, startRadius: 0, endRadius: 200
                )
            } else {
                LinearGradient(
                    colors: [Color(hex: bg.colorHex), Color(hex: endHex)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        } else {
            Color(hex: bg.colorHex)
        }
    }

    private var sizeBadge: some View {
        let s = viewModel.editState.selectedSize
        return Text("\(s.name)  \(Int(s.widthMM))×\(Int(s.heightMM))mm")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.45))
            .cornerRadius(8)
    }

    // MARK: - 上部ナビゲーションバー

    private var topNavBar: some View {
        HStack(spacing: 0) {
            // 戻るボタン
            Button {
                HapticFeedback.light()
                handleBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("戻る")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            Spacer()

            // タイトル
            Text(viewModel.currentStep.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // Undo / Redo（编辑モードのみ）
            if viewModel.currentStep == .editPhoto || viewModel.currentStep == .background {
                HStack(spacing: 4) {
                    Button {
                        HapticFeedback.light()
                        viewModel.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.canUndo ? .white : .white.opacity(0.3))
                    }
                    .disabled(!viewModel.canUndo)

                    Button {
                        HapticFeedback.light()
                        viewModel.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.canRedo ? .white : .white.opacity(0.3))
                    }
                    .disabled(!viewModel.canRedo)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            } else {
                Color.clear.frame(width: 60, height: 1)
            }
        }
        .padding(.top, uiTopInset)
        .padding(.horizontal, 4)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - 底部ツールバー（ステップ感知）

    @ViewBuilder
    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
            
            // 按钮工具栏
            HStack(spacing: 0) {
                // 尺寸选择按钮
                toolbarButton(
                    icon: "aspectratio",
                    label: "サイズ",
                    isActive: activeSheet == .size
                ) {
                    HapticFeedback.light()
                    activeSheet = .size
                }

                toolbarButton(icon: "crop", label: "構図", isActive: activeSheet == .crop) {
                    HapticFeedback.light()
                    activeSheet = .crop
                }

                // 背景按钮
                toolbarButton(
                    icon: "paintpalette.fill",
                    label: "背景",
                    isActive: activeSheet == .background
                ) {
                    HapticFeedback.light()
                    activeSheet = .background
                }

                // 美肌按钮
                toolbarButton(
                    icon: "sparkles",
                    label: "自然補正",
                    isActive: activeSheet == .beauty
                ) {
                    HapticFeedback.light()
                    beautyState = viewModel.editState.beauty
                    activeSheet = .beauty
                }

                // 回転按钮
                toolbarButton(icon: "rotate.left.fill", label: "回転") {
                    HapticFeedback.light()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.rotateLeft()
                    }
                }

                // 保存按钮
                toolbarButton(icon: "square.and.arrow.down.fill", label: "保存", isPrimary: true) {
                    HapticFeedback.medium()
                    advanceToExport()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(Color.black.opacity(0.85))
    }

    private func toolButton(
        icon: String,
        label: String,
        isActive: Bool = false,
        isHighlight: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconTint(isActive: isActive, isHighlight: isHighlight))
                Text(label)
                    .font(.system(size: 10, weight: isActive || isHighlight ? .semibold : .regular))
                    .foregroundColor(iconTint(isActive: isActive, isHighlight: isHighlight))
                // アクティブインジケーター
                Circle()
                    .fill(isActive ? Color.appPrimary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func iconTint(isActive: Bool, isHighlight: Bool) -> Color {
        if isHighlight { return Color.appPrimary }
        if isActive   { return Color.appPrimary }
        return .white
    }

    // MARK: - ツールバーボタン（编辑步骤用）

    private func toolbarButton(
        icon: String,
        label: String,
        isActive: Bool = false,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // 圆形背景
                    Circle()
                        .fill(isPrimary ? Color.appPrimary :
                              isActive ? Color.appPrimary.opacity(0.2) :
                              Color.white.opacity(0.1))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .font(.system(size: 17))
                        .foregroundColor(isPrimary ? .white :
                                        isActive ? Color.appPrimary : .white)
                }

                Text(label)
                    .font(.system(size: 9, weight: isPrimary ? .semibold : .regular))
                    .foregroundColor(isPrimary ? Color.appPrimary :
                                    isActive ? Color.appPrimary : .white.opacity(0.9))
            }
            .frame(minWidth: 60)  // 确保每个按钮有最小宽度
        }
        .buttonStyle(.plain)
    }

    // MARK: - シート内容

    @ViewBuilder
    private func sheetContent(for sheet: EditorSheet) -> some View {
        switch sheet {
        case .size:
            sizeSheetContent
        case .background:
            backgroundSheetContent
        case .beauty:
            beautySheetContent
        case .crop:
            VStack(spacing: 0) {
                sheetInlineHeader(title: "構図を調整") { activeSheet = nil }
                CropView(viewModel: viewModel)
            }
        case .repair:
            BackgroundRepairView(viewModel: viewModel)
        }
    }

    // ── サイズ選択シート（インラインコンパクト）──────────────────────────────

    private var sizeSheetContent: some View {
        VStack(spacing: 0) {
            sheetInlineHeader(title: "サイズを選択") {
                activeSheet = nil
            }
            SizePickerView(viewModel: viewModel)
        }
        .background(Color.appSurface)
    }

    // ── 背景シート（コンパクト・=inlineヘッダー + AI除去）─────────────────

    private var backgroundSheetContent: some View {
        VStack(spacing: 0) {
            // ─ カスタムインラインヘッダー ────────────────────────────────
            sheetInlineHeader(title: "背景色を選択") {
                activeSheet = nil
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // AI除去コントロール（コンパクト-inline）
                    aiBackgroundRemoveRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // セクション：プリセット単色
                    sectionHeader("証明写真プリセット", icon: "square.grid.2x2.fill")
                    colorPresetGrid
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // セクション：グラデーション
                    sectionHeader("グラデーション", icon: "rectangle.fill.on.rectangle.fill")
                    gradientPresetRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // セクション：カスタムカラー
                    sectionHeader("カスタムカラー", icon: "eyedropper.halffull")
                    customColorRow
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
        }
        .background(Color.appSurface)
        .sheet(isPresented: $showCustomPicker) {
            CustomColorPickerSheet(selectedColor: $customColor) { hex in
                viewModel.selectCustomBackground(hex: hex)
                showCustomPicker = false
            }
        }
    }

    // ── AI背景除去コントロール（inline compact）─────────────────────────────
    private var aiBackgroundRemoveRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.appPrimary, Color.appAccent],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("AI背景除去")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)
                        Text("自動")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.appAccent)
                            .cornerRadius(4)
                    }
                    Text("Vision AIで人物を自動切り抜き")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
                if viewModel.editState.backgroundRemoved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.appSuccess)
                }
            }

            Button {
                Task { await viewModel.removeBackground() }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.75)
                    }
                    Image(systemName: viewModel.editState.backgroundRemoved
                          ? "arrow.clockwise" : "wand.and.rays")
                    Text(viewModel.editState.backgroundRemoved
                         ? "背景除去をやり直す" : "AI背景除去を実行")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: viewModel.editState.backgroundRemoved
                            ? [Color(hex: "#3DAA6A"), Color(hex: "#27AE60")]
                            : [Color.appPrimary, Color.appAccent],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
            .disabled(viewModel.isProcessing)

            if viewModel.isProcessing {
                Text(viewModel.processingMessage)
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(14)
        .background(Color.appBackground)
        .cornerRadius(14)
    }

    private var colorPresetGrid: some View {
        let solidPresets = BackgroundColor.presets.filter { !$0.isGradient }
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 10
        ) {
            ForEach(solidPresets) { bg in
                BGColorCell(
                    background: bg,
                    isSelected: viewModel.editState.selectedBackground.id == bg.id
                ) {
                    HapticFeedback.selection()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectBackground(bg)
                    }
                }
            }
        }
    }

    private var gradientPresetRow: some View {
        let gradPresets = BackgroundColor.presets.filter { $0.isGradient }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(gradPresets) { bg in
                    BGGradientCell(
                        background: bg,
                        isSelected: viewModel.editState.selectedBackground.id == bg.id
                    ) {
                        HapticFeedback.selection()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectBackground(bg)
                        }
                    }
                }
            }
        }
    }

    @State private var showCustomPicker = false
    @State private var customColor: Color = .white

    private var customColorRow: some View {
        Button {
            showCustomPicker = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AngularGradient(
                            colors: [.red, .yellow, .green, .blue, .purple, .red],
                            center: .center
                        ))
                        .frame(width: 30, height: 30)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                }
                Text("カラーピッカーで選択")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
            }
            .padding(14)
            .background(Color.appBackground)
            .cornerRadius(12)
        }
    }

    // ── 肌を美しくシート（コンパクト・inlineヘッダー + 比較プレビュー）────────────

    private var beautySheetContent: some View {
        VStack(spacing: 0) {
            // ─ カスタムインラインヘッダー ────────────────────────────────
            sheetBeautyHeader

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ─ 比較プレビュー（トグル表示）───────────────────────
                    if showBeautyComparison {
                        EditorBeautyComparisonView(viewModel: viewModel)
                            .frame(height: 160)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    // プリセット行
                    presetRow
                        .padding(.bottom, 14)

                    // 肌補正スライダー
                    sectionHeader("肌補正", icon: "face.smiling.inverse")
                    VStack(spacing: 4) {
                        sheetBeautySlider(
                            title: "スムージング", icon: "face.smiling",
                            value: $beautyState.skinSmoothing, range: 0...1,
                            tint: Color(hex: "#FF8B5E")
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    // 明るさ・色味
                    sectionHeader("明るさ・色味", icon: "sun.max.fill")
                    VStack(spacing: 4) {
                        sheetBeautySlider(title: "明るさ",    icon: "sun.max.fill",
                                         value: $beautyState.brightness, range: -1...1, tint: Color(hex: "#FFD60A"))
                        sheetBeautySlider(title: "ハイライト", icon: "circle.lefthalf.filled",
                                         value: $beautyState.highlights, range: -1...1, tint: Color(hex: "#FFCC44"))
                        sheetBeautySlider(title: "シャドウ",   icon: "moon.fill",
                                         value: $beautyState.shadows,    range: -1...1, tint: Color(hex: "#8E8ECB"))
                        sheetBeautySlider(title: "色温度",     icon: "thermometer.medium",
                                         value: $beautyState.warmth,      range: -1...1, tint: Color(hex: "#FF6B35"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    Spacer(minLength: 20)
                }
                .padding(.top, 4)
            }
        }
        .background(Color.appSurface)
    }

    // ── 肌を美しくシート用インラインヘッダー（比較トグル + リセット + 完了）───────
    private var sheetBeautyHeader: some View {
        HStack(spacing: 0) {
            // 比較トグル
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBeautyComparison.toggle()
                }
            } label: {
                Label(
                    showBeautyComparison ? "比較を閉じる" : "補正前と比較",
                    systemImage: showBeautyComparison ? "xmark.circle.fill" : "rectangle.split.2x1.fill"
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(showBeautyComparison ? Color.appTextSecondary : Color.appPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(showBeautyComparison
                              ? Color.appDivider.opacity(0.3)
                              : Color.appPrimary.opacity(0.1))
                )
            }

            Spacer()

            // リセット
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    beautyState = BeautyParameters()
                    selectedPreset = .none
                }
                viewModel.updateBeauty(beautyState)
                viewModel.commitBeautyChange()
            } label: {
                Text("リセット")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appPrimary)
                    .opacity(beautyState.hasAnyAdjustment ? 1 : 0.35)
            }
            .disabled(!beautyState.hasAnyAdjustment)

            // 完了
            Button {
                viewModel.updateBeauty(beautyState)
                viewModel.commitBeautyChange()
                activeSheet = nil
            } label: {
                Text("完了")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.appPrimary)
                    .padding(.leading, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BeautyPreset.safeCases, id: \.self) { preset in
                    PresetChip(
                        title: preset.rawValue,
                        icon: preset.icon,
                        isSelected: selectedPreset == preset
                    ) {
                        selectedPreset = preset
                        beautyState   = preset.parameters
                        viewModel.updateBeauty(beautyState)
                        viewModel.commitBeautyChange()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func sheetBeautySlider(
        title: String, icon: String,
        value: Binding<Double>, range: ClosedRange<Double>,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(tint)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextPrimary)
                .frame(width: 76, alignment: .leading)
            Slider(value: value, in: range) { editing in
                if !editing {
                    viewModel.commitBeautyChange()
                } else {
                    viewModel.updateBeauty(beautyState)
                }
            }
            .tint(tint)
            Button {
                value.wrappedValue = range.lowerBound < 0 ? 0 : range.lowerBound
                viewModel.updateBeauty(beautyState)
            } label: {
                Text(sliderValueText(value.wrappedValue, range: range))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.appTextSecondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
    }

    private func sliderValueText(_ v: Double, range: ClosedRange<Double>) -> String {
        range.lowerBound < 0
            ? String(format: "%+.1f", v)
            : String(format: "%.1f", v)
    }

    // MARK: - セクションヘッダー

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(Color.appTextSecondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - インラインシートヘッダー（タイトル + 完了ボタン）

    private func sheetInlineHeader(title: String, onDone: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appTextPrimary)
            Spacer()
            Button("完了", action: onDone)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.appPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - ヘルパー

    private var uiTopInset: CGFloat {
        let key = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
        return max(key, 44)
    }

    private var uiBottomInset: CGFloat {
        let key = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
        return max(key, 20)
    }

    private func handleBack() {
        let prev = viewModel.currentStep.rawValue - 1
        if let step = PhotoEditorViewModel.EditStep(rawValue: prev) {
            withAnimation(.appSpring) {
                viewModel.currentStep = step
            }
        } else {
            dismiss()
        }
    }

    private func advanceToExport() {
        // 提交编辑更改
        viewModel.commitCropChange()
        viewModel.commitBeautyChange()
        
        // 跳转到导出步骤
        withAnimation(.appSpring) {
            viewModel.currentStep = .export
        }
    }
}

// MARK: - 背景カラーチェル

private struct BGColorCell: View {
    let background: BackgroundColor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Color(hex: background.colorHex)
                        .frame(height: 60)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? Color.appPrimary : Color.appDivider,
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(
                                background.colorHex == "#FFFFFF"
                                    ? Color.appPrimary : .white
                            )
                    }
                }
                .shadow(color: Color(hex: background.colorHex).opacity(0.3),
                        radius: isSelected ? 6 : 2, y: 2)
                Text(background.name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Color.appPrimary : Color.appTextSecondary)
            }
        }
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - エディター用美肌を比較プレビュー（ドラッグ比較スライダー）

private struct EditorBeautyComparisonView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var splitPosition: CGFloat = 0.5
    @GestureState private var dragging = false
    @State private var initialSplitPosition: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // After（補正後、右半分）
                if let edited = viewModel.editedImage {
                    Image(uiImage: edited)
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .clipped()
                }

                // Before（補正前、左半分・クリップ）
                if let original = viewModel.originalImage {
                    Image(uiImage: original)
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .clipped()
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle().frame(width: w * splitPosition)
                                Spacer()
                            }
                        )
                }

                // スプリットライン
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .offset(x: w * splitPosition - w / 2)

                // ドラッグハンドル
                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .overlay(
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black.opacity(0.6))
                    )
                    .offset(x: w * splitPosition - w / 2)

                // Before / After ラベル
                HStack {
                    Text("補正前")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(4)
                        .padding(8)
                    Spacer()
                    Text("補正後")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appPrimary.opacity(0.7))
                        .cornerRadius(4)
                        .padding(8)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .cornerRadius(10)
            .clipped()
            .gesture(
                DragGesture()
                    .onChanged { v in
                        let delta = v.translation.width / w
                        splitPosition = max(0.05, min(0.95, initialSplitPosition + delta))
                    }
                    .onEnded { _ in
                        initialSplitPosition = splitPosition
                    }
            )
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}



private struct BGGradientCell: View {
    let background: BackgroundColor
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    if background.isRadialGradient, let endHex = background.gradientEndHex {
                        RadialGradient(
                            colors: [Color(hex: background.colorHex), Color(hex: endHex)],
                            center: .center, startRadius: 0, endRadius: 55
                        )
                    } else if let endHex = background.gradientEndHex {
                        LinearGradient(
                            colors: [Color(hex: background.colorHex), Color(hex: endHex)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }
                .frame(width: 80, height: 60)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.appPrimary : Color.appDivider,
                                lineWidth: isSelected ? 2.5 : 1)
                )
                Text(background.name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Color.appPrimary : Color.appTextSecondary)
            }
        }
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - ステッププログレスバー（向导モードのみ使用）

struct EditorStepBar: View {
    let currentStep: PhotoEditorViewModel.EditStep

    private let steps: [PhotoEditorViewModel.EditStep] = [.selectSize, .editPhoto, .background, .export]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element) { idx, step in
                let isDone    = step.rawValue <  currentStep.rawValue
                let isCurrent = step.rawValue == currentStep.rawValue

                HStack(spacing: 0) {
                    ZStack {
                        if isCurrent {
                            Circle()
                                .stroke(Color.appPrimary.opacity(0.25), lineWidth: 3)
                                .frame(width: 34, height: 34)
                        }
                        Circle()
                            .fill(isDone || isCurrent ? Color.appPrimary : Color.appDivider)
                            .frame(width: 28, height: 28)
                            .shadow(color: (isDone || isCurrent) ? Color.appPrimary.opacity(0.35) : .clear,
                                    radius: 4, y: 2)

                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(idx + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isCurrent ? .white : Color.appTextSecondary)
                        }
                    }
                    .animation(.appSpring, value: currentStep)

                    Text(step.title)
                        .font(.system(size: isCurrent ? 10 : 9,
                                      weight: isCurrent ? .bold : .regular))
                        .foregroundColor(isCurrent ? Color.appPrimary
                                         : isDone ? Color.appTextSecondary.opacity(0.7)
                                         : Color.appTextSecondary.opacity(0.5))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.7)
                        .padding(.leading, 4)
                        .animation(.appEase, value: currentStep)

                    if idx < steps.count - 1 {
                        Rectangle()
                            .fill(isDone ? Color.appPrimary.opacity(0.5) : Color.appDivider)
                            .frame(height: 1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 4)
                            .animation(.appEase, value: currentStep)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appSurface)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - 処理中オーバーレイ

struct ProcessingOverlay: View {
    let message: String
    @State private var dotCount = 0
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 3)
                        .frame(width: 52, height: 52)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.3)
                }

                VStack(spacing: 4) {
                    Text(message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(String(repeating: ".", count: dotCount + 1))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .animation(.appFade, value: dotCount)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#0D1B2A").opacity(0.96),
                                     Color(hex: "#1A2B3C").opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 24)
            )
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dotCount = (dotCount + 1) % 3
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
