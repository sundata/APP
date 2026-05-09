import SwiftUI

// MARK: - 美肌コントロールビュー（全機能版）
struct BeautyControlView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var beauty: BeautyParameters = BeautyParameters()
    @State private var selectedPreset: BeautyPreset = .none
    @State private var showComparison: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ─── ヘッダー ───
            beautyHeader

            // ─── 比較プレビュー ───
            if showComparison {
                ComparisonPreview(viewModel: viewModel)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            // ─── プリセット行 ───
            presetRow
                .padding(.bottom, 16)

            // ─── 肌補正スライダー ───
            sectionHeader("肌補正", icon: "face.smiling.inverse")
            VStack(spacing: 4) {
                BeautySlider(title: "スムージング", icon: "face.smiling",
                             value: $beauty.skinSmoothing, range: 0...1,
                             tint: Color(hex: "#FF8B5E"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // ─── 明るさ・色味 ───
            sectionHeader("明るさ・色味", icon: "sun.max.fill")
            VStack(spacing: 4) {
                BeautySlider(title: "明るさ", icon: "sun.max.fill",
                             value: $beauty.brightness, range: -1...1,
                             tint: Color(hex: "#FFD60A"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
                BeautySlider(title: "ハイライト", icon: "circle.lefthalf.filled.righthalf.striped.horizontal.inverse",
                             value: $beauty.highlights, range: -1...1,
                             tint: Color(hex: "#FFCC44"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
                BeautySlider(title: "シャドウ", icon: "moon.fill",
                             value: $beauty.shadows, range: -1...1,
                             tint: Color(hex: "#8E8ECB"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
                BeautySlider(title: "色温度", icon: "thermometer.medium",
                             value: $beauty.warmth, range: -1...1,
                             tint: Color(hex: "#FF6B35"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .padding(.vertical, 4)
        .onAppear { beauty = viewModel.editState.beauty }
        .onChange(of: viewModel.editState.beauty) { newValue in
            beauty = newValue
        }
    }

    // ─────────────────────────────────────
    // MARK: ヘッダー
    // ─────────────────────────────────────
    private var beautyHeader: some View {
        HStack {
            Label("美肌補正", systemImage: "sparkles")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appTextPrimary)

            Spacer()

            // 比較ボタン
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showComparison.toggle()
                }
            } label: {
                Label(showComparison ? "閉じる" : "比較",
                      systemImage: showComparison ? "xmark.circle.fill" : "rectangle.split.2x1.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showComparison ? Color.appTextSecondary : Color.appPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(showComparison
                                  ? Color.appDivider.opacity(0.3)
                                  : Color.appPrimary.opacity(0.1))
                    )
            }

            // リセットボタン
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    beauty = BeautyParameters()
                    selectedPreset = .none
                    viewModel.updateBeauty(beauty)
                    viewModel.commitBeautyChange()
                }
            } label: {
                Text("リセット")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appPrimary)
            }
            .opacity(beauty.hasAnyAdjustment ? 1 : 0.3)
            .disabled(!beauty.hasAnyAdjustment)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    // ─────────────────────────────────────
    // MARK: プリセット行
    // ─────────────────────────────────────
    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BeautyPreset.allCases, id: \.self) { preset in
                    PresetChip(title: preset.rawValue,
                               icon: preset.icon,
                               isSelected: selectedPreset == preset) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedPreset = preset
                            beauty         = preset.parameters
                        }
                        viewModel.updateBeauty(beauty)
                        viewModel.commitBeautyChange()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // ─────────────────────────────────────
    // MARK: セクションヘッダー
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
        .padding(.bottom, 8)
    }
}

// MARK: - 調整コントロールビュー（全機能版）
struct AdjustmentControlView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var beauty: BeautyParameters = BeautyParameters()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ─── ヘッダー ───
            HStack {
                Label("画質調整", systemImage: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                Button {
                    beauty.contrast   = 0
                    beauty.saturation = 0
                    beauty.sharpness  = 0
                    beauty.fade       = 0
                    viewModel.updateBeauty(beauty)
                    viewModel.commitBeautyChange()
                } label: {
                    Text("リセット")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appPrimary)
                }
                .opacity((beauty.contrast != 0 || beauty.saturation != 0
                          || beauty.sharpness != 0 || beauty.fade != 0) ? 1 : 0.3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // ─── スライダー群 ───
            VStack(spacing: 4) {
                BeautySlider(title: "コントラスト", icon: "circle.lefthalf.filled",
                             value: $beauty.contrast, range: -1...1,
                             tint: Color(hex: "#5856D6"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
                BeautySlider(title: "彩度", icon: "paintpalette.fill",
                             value: $beauty.saturation, range: -1...1,
                             tint: Color(hex: "#FF2D55"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
                BeautySlider(title: "シャープ", icon: "rhombus.fill",
                             value: $beauty.sharpness, range: 0...1,
                             tint: Color(hex: "#34C759"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
                BeautySlider(title: "フェード", icon: "smoke.fill",
                             value: $beauty.fade, range: 0...1,
                             tint: Color(hex: "#8E8E93"),
                             onEditEnd: { viewModel.commitBeautyChange() }) {
                    viewModel.updateBeauty(beauty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .padding(.vertical, 4)
        .onAppear { beauty = viewModel.editState.beauty }
        .onChange(of: viewModel.editState.beauty) { newValue in
            beauty = newValue
        }
    }
}

// MARK: - 比較プレビュー（Before / After）
struct ComparisonPreview: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var splitPosition: CGFloat = 0.5
    @GestureState private var dragging = false
    @State private var initialSplitPosition: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // ─ After（右）
                if let edited = viewModel.editedImage {
                    Image(uiImage: edited)
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .clipped()
                }

                // ─ Before（左、クリップ）
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

                // ─ スプリットライン
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .offset(x: w * splitPosition - w / 2)

                // ─ ドラッグハンドル
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .overlay(
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black.opacity(0.6))
                    )
                    .offset(x: w * splitPosition - w / 2)

                // ─ ラベル

                // ─ ラベル
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
        .frame(height: 160)
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

// MARK: - 美肌スライダー（onEditEnd対応版）
struct BeautySlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var tint: Color = Color.appPrimary
    var onEditEnd: (() -> Void)? = nil
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // アイコン
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(tint)
            }

            // タイトル
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextPrimary)
                .frame(width: 80, alignment: .leading)

            // スライダー
            Slider(value: $value, in: range) { editing in
                if !editing { onEditEnd?() }
                onChange()
            }
            .tint(tint)

            // 値ラベル（タップでリセット）
            Button {
                value = range.lowerBound < 0 ? 0 : range.lowerBound
                onChange()
                onEditEnd?()
            } label: {
                Text(valueText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(isZero ? Color.appTextSecondary : tint)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 2)
    }

    private var isZero: Bool {
        range.lowerBound < 0 ? value == 0 : value == range.lowerBound
    }

    private var valueText: String {
        range.lowerBound < 0
            ? String(format: "%+.1f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - プリセットチップ（アイコン付き）
struct PresetChip: View {
    let title: String
    var icon: String = ""
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.appPrimary : Color(hex: "#F0F2F5"))
                        .frame(width: 40, height: 40)
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? .white : Color.appTextSecondary)
                    }
                    if isSelected {
                        Circle()
                            .stroke(Color.appPrimary.opacity(0.5), lineWidth: 2)
                            .frame(width: 46, height: 46)
                    }
                }
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Color.appPrimary : Color.appTextSecondary)
            }
            .frame(width: 60)
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            Divider()
            BeautyControlView(viewModel: PhotoEditorViewModel())
            Divider()
            AdjustmentControlView(viewModel: PhotoEditorViewModel())
        }
    }
    .background(Color.appBackground)
}
