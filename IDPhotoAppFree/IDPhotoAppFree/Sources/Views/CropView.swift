import SwiftUI

// MARK: - クロップビュー（フル機能版）
struct CropView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel

    // ジェスチャー状態
    @State private var scale:        CGFloat = 1.0
    @State private var lastScale:    CGFloat = 1.0
    @State private var offset:       CGSize  = .zero
    @State private var lastOffset:   CGSize  = .zero

    // グリッド表示フラグ（ドラッグ中のみ表示）
    @State private var showGrid:     Bool = false

    // 回転微調整スライダー
    @State private var fineRotation: Double = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ─── ツールバー ───
            cropToolbar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

            // ─── クロッププレビュー ───
            cropPreview
                .padding(.horizontal, 20)

            // ─── 回転スライダー ───
            rotationSlider
                .padding(.horizontal, 24)
                .padding(.top, 14)

            // ─── ヒントテキスト ───
            Text("ピンチでズーム・ドラッグで位置を調整 / 左右スワイプで微回転")
                .font(.system(size: 11))
                .foregroundColor(Color.appTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }

    // ─────────────────────────────────────
    // MARK: ツールバー
    // ─────────────────────────────────────
    private var cropToolbar: some View {
        HStack(spacing: 0) {
            // タイトル
            Label("切り取り", systemImage: "crop")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.appTextPrimary)

            Spacer()

            // Undo
            toolButton(icon: "arrow.uturn.backward",
                       enabled: viewModel.canUndo) {
                viewModel.undo()
            }
            // Redo
            toolButton(icon: "arrow.uturn.forward",
                       enabled: viewModel.canRedo) {
                viewModel.redo()
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 8)

            // 左90°回転
            toolButton(icon: "rotate.left.fill", enabled: true) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.rotateLeft()
                    syncFromViewModel()
                }
            }
            // 右90°回転
            toolButton(icon: "rotate.right.fill", enabled: true) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.rotateRight()
                    syncFromViewModel()
                }
            }
            // 水平フリップ
            toolButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill", enabled: true) {
                viewModel.flipHorizontal()
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 8)

            // リセット
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    scale       = 1.0
                    lastScale   = 1.0
                    offset      = .zero
                    lastOffset  = .zero
                    fineRotation = 0.0
                    viewModel.resetCrop()
                }
            } label: {
                Text("リセット")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.appPrimary)
            }
        }
    }

    private func toolButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(enabled ? Color.appTextPrimary : Color.appDivider)
                .frame(width: 36, height: 36)
        }
        .disabled(!enabled)
    }

    // ─────────────────────────────────────
    // MARK: クロッププレビュー
    // ─────────────────────────────────────
    private var cropPreview: some View {
        GeometryReader { geo in
            let aspect = viewModel.editState.selectedSize.aspectRatio
            let w      = geo.size.width
            let h      = w / aspect

            ZStack {
                // 背景（半透明黒）
                Color.black.opacity(0.85)

                if let image = viewModel.originalImage {
                    // 写真
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(viewModel.editState.cropState.rotation + fineRotation))
                        .scaleEffect(scale)
                        .offset(offset)
                        // フリップ
                        .scaleEffect(x: viewModel.editState.cropState.flipHorizontal ? -1 : 1, y: 1)
                        .gesture(dragGesture)
                        .gesture(magnificationGesture)
                        .frame(width: w, height: h)
                        .clipped()
                }

                // グリッドオーバーレイ（ドラッグ中のみ）
                if showGrid {
                    CropGridOverlay(width: w, height: h)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: showGrid)
                }

                // 常時表示の外枠 + コーナーマーカー
                CropBorderOverlay(width: w, height: h)
            }
            .frame(width: w, height: h)
            .cornerRadius(10)
            .clipped()
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .onAppear {
                viewModel.cropViewSize = CGSize(width: w, height: h)
            }
            .onChange(of: geo.size) { newSize in
                let newW = newSize.width
                let newH = newW / aspect
                viewModel.cropViewSize = CGSize(width: newW, height: newH)
            }
        }
        .aspectRatio(viewModel.editState.selectedSize.aspectRatio, contentMode: .fit)
        .frame(maxHeight: 320)
    }

    // ─────────────────────────────────────
    // MARK: 回転微調整スライダー
    // ─────────────────────────────────────
    private var rotationSlider: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "rotate.3d")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                Text("微調整")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
                Text(String(format: "%+.1f°", fineRotation))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(fineRotation == 0 ? Color.appTextSecondary : Color.appPrimary)
            }

            // 目盛り付きスライダー
            ZStack {
                // 目盛り線
                tickMarks

                Slider(value: $fineRotation, in: -15...15) { editing in
                    if !editing {
                        // 指を離したとき cropState に反映
                        viewModel.editState.cropState.rotation += fineRotation
                        fineRotation = 0
                        viewModel.commitCropChange()
                    }
                }
                .tint(Color.appPrimary)
            }
        }
    }

    @ViewBuilder
    private var tickMarks: some View {
        GeometryReader { geo in
            let count = 30
            ForEach(0...count, id: \.self) { i in
                let ratio = CGFloat(i) / CGFloat(count)
                let x     = ratio * geo.size.width
                let isMajor = i % 5 == 0
                Rectangle()
                    .fill(isMajor ? Color.appTextSecondary.opacity(0.5) : Color.appDivider.opacity(0.6))
                    .frame(width: 1, height: isMajor ? 10 : 5)
                    .position(x: x, y: geo.size.height / 2)
            }
        }
        .frame(height: 20)
    }

    // ─────────────────────────────────────
    // MARK: ジェスチャー
    // ─────────────────────────────────────
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                withAnimation(.interactiveSpring()) {
                    offset    = CGSize(width:  lastOffset.width  + v.translation.width,
                                      height: lastOffset.height + v.translation.height)
                    showGrid  = true
                }
            }
            .onEnded { _ in
                lastOffset = offset
                withAnimation { showGrid = false }
                pushCropStateToViewModel()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { v in
                scale = max(1.0, min(5.0, lastScale * v))
                showGrid = true
            }
            .onEnded { _ in
                lastScale = scale
                withAnimation { showGrid = false }
                pushCropStateToViewModel()
            }
    }

    // ─────────────────────────────────────
    // MARK: ヘルパー
    // ─────────────────────────────────────
    private func pushCropStateToViewModel() {
        var s         = viewModel.editState.cropState
        s.scale       = scale
        s.offset      = offset
        viewModel.updateCropState(s)
        // クロップ操作完了時に確定
        viewModel.commitCropChange()
    }

    private func syncFromViewModel() {
        let s  = viewModel.editState.cropState
        scale       = s.scale
        lastScale   = s.scale
        offset      = s.offset
        lastOffset  = s.offset
    }
}

// ─────────────────────────────────────
// MARK: - グリッドオーバーレイ
// ─────────────────────────────────────
struct CropGridOverlay: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Path { path in
            for i in 1..<3 {
                let x = width * CGFloat(i) / 3
                path.move(to: .init(x: x, y: 0))
                path.addLine(to: .init(x: x, y: height))
            }
            for i in 1..<3 {
                let y = height * CGFloat(i) / 3
                path.move(to: .init(x: 0, y: y))
                path.addLine(to: .init(x: width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.45), lineWidth: 0.7)
        .frame(width: width, height: height)
    }
}

// ─────────────────────────────────────
// MARK: - 外枠 + コーナーマーカー
// ─────────────────────────────────────
struct CropBorderOverlay: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .frame(width: width, height: height)
            CropCorners(width: width, height: height)
        }
        .frame(width: width, height: height)
    }
}

/// 四隅コーナーマーカー
struct CropCorners: View {
    let width: CGFloat
    let height: CGFloat
    private let len: CGFloat   = 20
    private let thick: CGFloat = 3

    var body: some View {
        ZStack {
            corner(x: 0,     y: 0,      hFlip: false, vFlip: false)
            corner(x: width, y: 0,      hFlip: true,  vFlip: false)
            corner(x: 0,     y: height, hFlip: false, vFlip: true)
            corner(x: width, y: height, hFlip: true,  vFlip: true)
        }
        .frame(width: width, height: height)
    }

    private func corner(x: CGFloat, y: CGFloat, hFlip: Bool, vFlip: Bool) -> some View {
        Path { path in
            let hs: CGFloat = hFlip ? -1 : 1
            let vs: CGFloat = vFlip ? -1 : 1
            path.move(to:    CGPoint(x: x + hs * len, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + vs * len))
        }
        .stroke(Color.white, lineWidth: thick)
    }
}
