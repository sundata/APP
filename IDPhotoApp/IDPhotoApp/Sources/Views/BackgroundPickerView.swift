import SwiftUI

// MARK: - 背景選択画面（フル機能版）
struct BackgroundPickerView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel

    // UI 状態
    @State private var selectedTab: BgTab = .color
    @State private var showCustomColorPicker = false
    @State private var customColor: Color = .white
    @State private var showAITip = false
    @State private var bgRemovedPreview: UIImage?

    enum BgTab: String, CaseIterable {
        case color  = "背景カラー"
        case ai     = "AI除去"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ─── プレビューパネル ───
            previewPanel

            // ─── タブ切替 ───
            bgTabBar

            // ─── タブコンテンツ ───
            ScrollView(showsIndicators: false) {
                Group {
                    switch selectedTab {
                    case .color: colorPanel
                    case .ai:    aiPanel
                    }
                }
                .padding(.bottom, 32)
            }
            .frame(maxHeight: .infinity) // 残りのスペースを埋める
        }
        .onChange(of: viewModel.backgroundRemovedImage) { newVal in
            bgRemovedPreview = newVal
        }
        .sheet(isPresented: $showCustomColorPicker) {
            CustomColorPickerSheet(selectedColor: $customColor) { hex in
                viewModel.selectCustomBackground(hex: hex)
                showCustomColorPicker = false
            }
        }
    }

    // ─────────────────────────────────────
    // MARK: プレビューパネル
    // ─────────────────────────────────────
    private var previewPanel: some View {
        ZStack {
            Color(hex: "#0D1B2A")

            // ぼかし背景（finalImageを使用してクロップ適用済みの画像を表示）
            if let img = viewModel.finalImage ?? viewModel.editedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 20)
                    .opacity(0.3)
                    .clipped()
            }

            HStack(spacing: 24) {
                // ─ メインプレビュー（背景合成済み）
                VStack(spacing: 8) {
                    ZStack {
                        if viewModel.editState.backgroundRemoved {
                            // 背景除去済みの場合は背景色を適用
                            backgroundSwatchView(for: viewModel.editState.selectedBackground)
                                .frame(width: 110, height: 143)
                                .cornerRadius(10)

                            // finalImage（クロップ適用済み）を使用
                            if let img = viewModel.finalImage ?? viewModel.editedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 110, height: 143)
                                    .cornerRadius(10)
                            }
                        } else {
                            // 背景除去前はfinalImage（クロップ適用済み）を表示
                            if let img = viewModel.finalImage ?? viewModel.editedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 110, height: 143)
                                    .cornerRadius(10)
                                    .background(Color.black.opacity(0.3))
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

                    Text("現在の背景")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                // ─ 矢印
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))

                // ─ AI除去済みプレビュー（除去済みのみ表示）
                if viewModel.editState.backgroundRemoved,
                   let removed = bgRemovedPreview ?? viewModel.backgroundRemovedImage {
                    VStack(spacing: 8) {
                        ZStack {
                            // チェッカーパターン（透明を表現）
                            CheckerPatternView()
                                .frame(width: 110, height: 143)
                                .cornerRadius(10)
                                .clipped()
                            Image(uiImage: removed)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110, height: 143)
                                .cornerRadius(10)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.appAccent.opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

                        Text("背景除去済み")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.appAccent)
                    }
                } else {
                    // AI除去の案内
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.07))
                                .frame(width: 110, height: 143)
                            VStack(spacing: 6) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white.opacity(0.5))
                                Text("AI除去で\nきれいに合成")
                                    .font(.system(size: 11))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                        Text("除去後のプレビュー")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .frame(height: 220)
        .clipped()
    }

    // ─────────────────────────────────────
    // MARK: タブバー
    // ─────────────────────────────────────
    private var bgTabBar: some View {
        HStack(spacing: 0) {
            ForEach(BgTab.allCases, id: \.self) { tab in
                Button {
                    HapticFeedback.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: selectedTab == tab ? .bold : .regular))
                        .foregroundColor(selectedTab == tab ? Color.appPrimary : Color.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(selectedTab == tab ? Color.appPrimary : Color.clear)
                                    .frame(height: 2.5)
                                    .cornerRadius(1.5)
                            }
                        )
                }
            }
        }
        .background(Color.appSurface)
        .overlay(Divider(), alignment: .bottom)
    }

    // ─────────────────────────────────────
    // MARK: カラーパネル
    // ─────────────────────────────────────
    private var colorPanel: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ─ セクション：プリセット単色
            sectionHeader("証明写真プリセット", icon: "square.grid.2x2.fill")
            colorPresetGrid
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            // ─ セクション：グラデーション
            sectionHeader("グラデーション", icon: "rectangle.fill.on.rectangle.fill")
            gradientPresetRow
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            // ─ セクション：カスタムカラー
            sectionHeader("カスタムカラー", icon: "eyedropper.halffull")
            customColorRow
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .padding(.top, 20)
    }

    // ─────────────────────────────────────
    // MARK: AIパネル
    // ─────────────────────────────────────
    private var aiPanel: some View {
        VStack(spacing: 16) {

            // AI除去カード
            aiRemoveCard
                .padding(.horizontal, 20)

            // 使い方ガイド
            aiGuideCard
                .padding(.horizontal, 20)

            // 除去済みの場合：再合成オプション
            if viewModel.editState.backgroundRemoved {
                recompositeSection
                    .padding(.horizontal, 20)
            }

            Spacer(minLength: 20)
        }
        .padding(.top, 20)
    }

    // ─────────────────────────────────────
    // MARK: カラーグリッド
    // ─────────────────────────────────────
    private var colorPresetGrid: some View {
        let solidPresets = BackgroundColor.presets.filter { !$0.isGradient }
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 10
        ) {
            ForEach(solidPresets) { bg in
                BackgroundColorCell(
                    background: bg,
                    isSelected: viewModel.editState.selectedBackground.id == bg.id
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectBackground(bg)
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────
    // MARK: グラデーション行
    // ─────────────────────────────────────
    private var gradientPresetRow: some View {
        let gradPresets = BackgroundColor.presets.filter { $0.isGradient }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(gradPresets) { bg in
                    BackgroundGradientCell(
                        background: bg,
                        isSelected: viewModel.editState.selectedBackground.id == bg.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectBackground(bg)
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────
    // MARK: カスタムカラー行
    // ─────────────────────────────────────
    private var customColorRow: some View {
        HStack(spacing: 12) {
            // カスタムカラー選択ボタン
            Button {
                showCustomColorPicker = true
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
                .cardStyle(cornerRadius: 12, shadowRadius: 4)
            }
        }
    }

    // ─────────────────────────────────────
    // MARK: AI除去カード
    // ─────────────────────────────────────
    private var aiRemoveCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.appPrimary, Color.appAccent],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("AI背景除去")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)
                        Text("自動")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.appAccent)
                            .cornerRadius(5)
                    }
                    Text("Vision AIが人物を自動検出・精細に切り抜き")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
                if viewModel.editState.backgroundRemoved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.appSuccess)
                }
            }

            // 実行ボタン
            Button {
                Task { await viewModel.removeBackground() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.editState.backgroundRemoved
                          ? "arrow.clockwise" : "wand.and.rays")
                    Text(viewModel.editState.backgroundRemoved
                         ? "背景除去をやり直す" : "AI背景除去を実行")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .buttonStyle(AIRemoveButtonStyle(isDone: viewModel.editState.backgroundRemoved))
            .disabled(viewModel.isProcessing)

            if viewModel.isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                    Text(viewModel.processingMessage)
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // ─────────────────────────────────────
    // MARK: 使い方ガイドカード
    // ─────────────────────────────────────
    private var aiGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("使い方のポイント", systemImage: "lightbulb.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.appWarning)

            VStack(alignment: .leading, spacing: 8) {
                aiTip(icon: "person.fill",       text: "正面向きの顔写真が最適です")
                aiTip(icon: "light.max",         text: "明るく撮影した写真ほど精度が向上します")
                aiTip(icon: "rectangle.fill",    text: "無地背景・複雑背景どちらも対応")
                aiTip(icon: "iphone.homebutton", text: "iOS 15以上のVision AIを使用しています")
            }
        }
        .padding(14)
        .background(Color.appWarning.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appWarning.opacity(0.2), lineWidth: 1)
        )
    }

    private func aiTip(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color.appWarning)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color.appTextSecondary)
        }
    }

    // ─────────────────────────────────────
    // MARK: 再合成セクション（AI除去済み時）
    // ─────────────────────────────────────
    private var recompositeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("除去後に背景カラーを選択", systemImage: "paintbrush.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.appTextPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BackgroundColor.presets.filter { !$0.isGradient }) { bg in
                        Button {
                            viewModel.selectBackground(bg)
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    if bg.isGradient, let end = bg.gradientEndHex {
                                        LinearGradient(
                                            colors: [Color(hex: bg.colorHex), Color(hex: end)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    } else {
                                        Color(hex: bg.colorHex)
                                    }
                                    if viewModel.editState.selectedBackground.id == bg.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(bg.colorHex == "#FFFFFF" ? Color.appPrimary : .white)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            viewModel.editState.selectedBackground.id == bg.id
                                                ? Color.appPrimary : Color.appDivider,
                                            lineWidth: viewModel.editState.selectedBackground.id == bg.id ? 2.5 : 1
                                        )
                                )

                                Text(bg.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .cardStyle(cornerRadius: 14, shadowRadius: 4)
    }

    // ─────────────────────────────────────
    // MARK: ヘルパー
    // ─────────────────────────────────────
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

    @ViewBuilder
    private func backgroundSwatchView(for bg: BackgroundColor) -> some View {
        if bg.isGradient, let endHex = bg.gradientEndHex {
            if bg.isRadialGradient {
                RadialGradient(
                    colors: [Color(hex: bg.colorHex), Color(hex: endHex)],
                    center: .center, startRadius: 0, endRadius: 100
                )
            } else {
                LinearGradient(
                    colors: [Color(hex: bg.colorHex), Color(hex: endHex)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        } else {
            Color(hex: bg.colorHex)
        }
    }
}

// MARK: - 背景カラーセル（コンパクト版）
struct BackgroundColorCell: View {
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
                            .foregroundColor(background.colorHex == "#FFFFFF"
                                             ? Color.appPrimary : .white)
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

// MARK: - グラデーションセル
struct BackgroundGradientCell: View {
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

// MARK: - チェッカーパターン（透明表示）
struct CheckerPatternView: View {
    var tileSize: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let cols = Int(ceil(size.width  / tileSize))
                let rows = Int(ceil(size.height / tileSize))
                for row in 0..<rows {
                    for col in 0..<cols {
                        let isLight = (row + col) % 2 == 0
                        let color: Color = isLight
                            ? Color(white: 0.88)
                            : Color(white: 0.72)
                        ctx.fill(
                            Path(CGRect(x: CGFloat(col) * tileSize,
                                        y: CGFloat(row) * tileSize,
                                        width: tileSize, height: tileSize)),
                            with: .color(color)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - カスタムカラーピッカーシート
struct CustomColorPickerSheet: View {
    @Binding var selectedColor: Color
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // ネイティブカラーピッカー
                ColorPicker("カラーを選択", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .scaleEffect(1.5)
                    .frame(height: 200)

                // プレビュー
                selectedColor
                    .frame(height: 80)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appDivider, lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                Text("選択したカラーが背景に適用されます")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    let hex = hexFromColor(selectedColor)
                    onConfirm(hex)
                } label: {
                    Text("この色を適用")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
            }
            .padding(.top, 30)
            .navigationTitle("カスタムカラー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(Color.appPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func hexFromColor(_ color: Color) -> String {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - AI除去ボタンスタイル
struct AIRemoveButtonStyle: ButtonStyle {
    let isDone: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isDone {
                        LinearGradient(
                            colors: [Color(hex: "#3DAA6A"), Color(hex: "#27AE60")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appAccent],
                            startPoint: .leading, endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(12)
            .shadow(color: (isDone ? Color(hex: "#27AE60") : Color.appPrimary).opacity(0.35),
                    radius: 6, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        BackgroundPickerView(viewModel: PhotoEditorViewModel())
    }
}
