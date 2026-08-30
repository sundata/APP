import SwiftUI
import Photos

// MARK: - 書き出し・保存画面（フルリニューアル）
struct ExportView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @EnvironmentObject private var adManager: AdManager

    // UI State
    @State private var isSaving        = false
    @State private var saveResult: SaveResult? = nil
    @State private var showShareSheet  = false
    @State private var shareItems: [Any] = []
    @State private var showPermAlert   = false
    @State private var previewLayout: ExportOptions.PrintLayout = .single
    @State private var layoutPreviewImage: UIImage? = nil
    @State private var isGeneratingPreview = false

    enum SaveResult: Equatable {
        case success, failure(String)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // 上部に返回ボタン分の余白
                    Color.clear.frame(height: 56)

                    // ① プレビューセクション
                    previewSection
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                    // ② 証明写真情報カード
                    infoCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // ③ 印刷レイアウト選択
                    layoutSection
                        .padding(.bottom, 20)

                    // ④ フォーマット・品質
                    formatSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    // ⑤ アクションボタン
                    actionButtons
                        .padding(.horizontal, 20)

                    Spacer(minLength: 120)
                }
            }

            // 返回按钮（固定在左上角）
            HStack {
                Button {
                    HapticFeedback.light()
                    withAnimation(.appSpring) {
                        viewModel.currentStep = .editPhoto
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("編集に戻る")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color.appPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                Spacer()
            }
            .background(Color.appBackground.opacity(0.95))
            .frame(height: 56)
        }
        // 保存結果トースト
        .overlay(alignment: .bottom) {
            if let result = saveResult {
                toastView(result: result)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.appSpring, value: saveResult)
        // 共有シート
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        // 権限アラート
        .alert("フォトライブラリへのアクセス", isPresented: $showPermAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("写真を保存するには、設定アプリでフォトライブラリへのアクセスを許可してください。")
        }
        .onChange(of: previewLayout) { _ in
            Task { await generateLayoutPreview() }
        }
        .onChange(of: viewModel.finalImage) { _ in
            // 最終画像が更新されたらプレビューも再生成
            Task { await generateLayoutPreview() }
        }
        .task {
            await generateLayoutPreview()
        }
    }

    // ─────────────────────────────
    // MARK: ① プレビューセクション
    // ─────────────────────────────
    private var previewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("完成プレビュー")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.appTextSecondary)
                    .padding(.horizontal, 20)
                Spacer()
                if previewLayout != .single {
                    Text("印刷レイアウト")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appPrimary)
                        .padding(.horizontal, 20)
                }
            }

            ZStack {
                Color(hex: "#0D1B2A")
                    .frame(height: 260)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)

                if isGeneratingPreview {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("プレビュー生成中...")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else if let preview = layoutPreviewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 240)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                } else if let img = viewModel.finalImage ?? viewModel.editedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 240)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                }

                // サイズバッジ
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        let s = viewModel.editState.selectedSize
                        Text("\(Int(s.widthMM))×\(Int(s.heightMM))mm · \(s.widthPx)×\(s.heightPx)px")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(6)
                            .padding(.trailing, 12)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    // ─────────────────────────────
    // MARK: ② 証明写真情報カード
    // ─────────────────────────────
    private var infoCard: some View {
        let size = viewModel.editState.selectedSize
        let bg   = viewModel.editState.selectedBackground

        return VStack(spacing: 0) {
            infoRow(icon: "ruler", label: "サイズ",
                    value: "\(size.name)  \(Int(size.widthMM)) × \(Int(size.heightMM)) mm")
            Divider().padding(.leading, 44)
            infoRow(icon: "camera.aperture", label: "解像度",
                    value: "\(size.widthPx) × \(size.heightPx) px · \(size.dpi) dpi")
            Divider().padding(.leading, 44)
            infoRow(icon: "paintbrush.fill", label: "背景色", value: bg.name)
            Divider().padding(.leading, 44)
            infoRow(icon: "doc.text", label: "用途", value: size.description)
        }
        .background(Color.appSurface)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color.appPrimary)
                .frame(width: 20)
                .padding(.leading, 12)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color.appTextSecondary)
                .frame(width: 60, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 11)
    }

    // ─────────────────────────────
    // MARK: ③ 印刷レイアウト選択
    // ─────────────────────────────
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("印刷レイアウト")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appTextPrimary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ExportOptions.PrintLayout.allCases) { layout in
                        LayoutCard(
                            layout: layout,
                            isSelected: previewLayout == layout
                        ) {
                            HapticFeedback.selection()
                            withAnimation(.appQuickSpring) {
                                previewLayout = layout
                                viewModel.exportOptions.layout = layout
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // ─────────────────────────────
    // MARK: ④ フォーマット・品質
    // ─────────────────────────────
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("保存形式")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appTextPrimary)

            // JPEG / PNG セレクタ
            HStack(spacing: 10) {
                ForEach(ExportOptions.ExportFormat.allCases) { fmt in
                    Button {
                        withAnimation { viewModel.exportOptions.format = fmt }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.exportOptions.format == fmt
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundColor(viewModel.exportOptions.format == fmt
                                                 ? Color.appPrimary : Color.appTextSecondary)
                            Text(fmt.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(viewModel.exportOptions.format == fmt
                                                 ? Color.appTextPrimary : Color.appTextSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.exportOptions.format == fmt
                                      ? Color.appPrimary.opacity(0.1)
                                      : Color.appDivider.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(viewModel.exportOptions.format == fmt
                                                ? Color.appPrimary.opacity(0.5) : Color.clear,
                                                lineWidth: 1.5)
                                )
                        )
                    }
                }
            }

            // JPEG品質スライダー（JPEGのみ）
            if viewModel.exportOptions.format == .jpeg {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("JPEG品質")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextSecondary)
                        Spacer()
                        Text("\(Int(viewModel.exportOptions.jpegQuality * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.appPrimary)
                    }
                    Slider(value: $viewModel.exportOptions.jpegQuality, in: 0.6...1.0, step: 0.05)
                        .tint(Color.appPrimary)

                    HStack {
                        Text("ファイルサイズ小")
                            .font(.system(size: 10))
                            .foregroundColor(Color.appTextSecondary)
                        Spacer()
                        Text("最高画質")
                            .font(.system(size: 10))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                .padding(12)
                .background(Color.appDivider.opacity(0.2))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ヒントテキスト
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
                Text(viewModel.exportOptions.format == .jpeg
                     ? "JPEGは最もファイルサイズが小さく、印刷・提出に適しています"
                     : "PNGは透明背景をサポートします（背景除去済みの場合）")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // ─────────────────────────────
    // MARK: ⑤ アクションボタン
    // ─────────────────────────────
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // フォトライブラリに保存
            Button {
                Task { await saveToLibrary() }
            } label: {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                    Text(isSaving ? "保存中..." : "フォトライブラリに保存")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Color(hex: "#2A7EF5"), Color(hex: "#1A5FC7")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(isSaving)

            // 共有・他アプリ
            Button {
                HapticFeedback.light()
                Task { await shareImage() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("共有・その他のアプリで開く")
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(Color.appPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.appPrimary, lineWidth: 1.5)
                )
            }
        }
    }

    // ─────────────────────────────
    // MARK: トーストビュー
    // ─────────────────────────────
    @ViewBuilder
    private func toastView(result: SaveResult) -> some View {
        switch result {
        case .success:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("フォトライブラリに保存しました ✓")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "#1A2B3C").opacity(0.92))
            .cornerRadius(30)

        case .failure(let msg):
            HStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "#3A1B1B").opacity(0.92))
            .cornerRadius(30)
        }
    }

    // ─────────────────────────────
    // MARK: 処理ロジック
    // ─────────────────────────────
    private func generateLayoutPreview() async {
        guard let base = viewModel.finalImage ?? viewModel.editedImage else { return }
        isGeneratingPreview = true
        let size    = viewModel.editState.selectedSize
        let layout  = previewLayout
        let service = viewModel.exportService

        let targetSize = CGSize(width: size.widthPx, height: size.heightPx)
        let resized = await Task.detached(priority: .userInitiated) { [imageService = ImageService()] in
            imageService.resizeImage(base, to: targetSize)
        }.value

        let result = await Task.detached(priority: .userInitiated) {
            service.renderLayout(resized, size: size, layout: layout)
        }.value

        await MainActor.run {
            layoutPreviewImage = result
            isGeneratingPreview = false
        }
    }

    private func saveToLibrary() async {
        guard let base = viewModel.finalImage ?? viewModel.editedImage else { return }
        await MainActor.run {
            isSaving = true
            saveResult = nil
        }

        // 権限チェック
        let permitted = await viewModel.exportService.requestPhotoLibraryPermission()
        guard permitted else {
            await MainActor.run {
                isSaving = false
                showPermAlert = true
            }
            return
        }

        let opts = viewModel.exportOptions
        let size = viewModel.editState.selectedSize
        let result = await viewModel.exportService.export(image: base, size: size, options: opts)

        await MainActor.run {
            isSaving = false
            switch result {
            case .success:
                HapticFeedback.success()
                saveResult = .success
                // 保存成功後にインタースティシャル広告を表示
                if let root = adManager.currentRootViewController() {
                    adManager.showInterstitial(from: root)
                }
            case .failure(let e):
                HapticFeedback.error()
                if case .permissionDenied = e {
                    showPermAlert = true
                } else {
                    saveResult = .failure(e.localizedDescription)
                }
            }
        }

        await clearSaveResultAfterDelay()
    }

    private func clearSaveResultAfterDelay() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run { saveResult = nil }
    }

    private func shareImage() async {
        guard let base = viewModel.finalImage ?? viewModel.editedImage else { return }
        let opts   = viewModel.exportOptions
        let size   = viewModel.editState.selectedSize
        let service = viewModel.exportService

        let targetSize = CGSize(width: size.widthPx, height: size.heightPx)
        let resized = await Task.detached(priority: .userInitiated) { [imageService = ImageService()] in
            imageService.resizeImage(base, to: targetSize)
        }.value

        let layoutImg = await Task.detached(priority: .userInitiated) {
            service.renderLayout(resized, size: size, layout: opts.layout) ?? resized
        }.value

        guard let data = service.imageData(for: layoutImg, format: opts.format, quality: opts.jpegQuality) else {
            await MainActor.run {
                saveResult = .failure("画像の書き出しに失敗しました")
                HapticFeedback.error()
            }
            await clearSaveResultAfterDelay()
            return
        }

        let ext  = opts.format == .jpeg ? "jpg" : "png"
        let url  = FileManager.default.temporaryDirectory
            .appendingPathComponent("idphoto_\(size.id).\(ext)")
        do {
            try data.write(to: url)
        } catch {
            await MainActor.run {
                saveResult = .failure("画像の保存に失敗しました")
                HapticFeedback.error()
            }
            await clearSaveResultAfterDelay()
            return
        }

        await MainActor.run {
            shareItems = [url]
            showShareSheet = true
        }
    }
}

// ─────────────────────────────
// MARK: - レイアウト選択カード
// ─────────────────────────────

struct LayoutCard: View {
    let layout: ExportOptions.PrintLayout
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.appPrimary.opacity(0.12) : Color.appDivider.opacity(0.35))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 1.5)
                        )

                    Image(systemName: layout.icon)
                        .font(.system(size: 26))
                        .foregroundColor(isSelected ? Color.appPrimary : Color.appTextSecondary)
                }
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(layout.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? Color.appPrimary : Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        }
    }
}

// ─────────────────────────────
// MARK: - シェアシート
// ─────────────────────────────
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ExportView(viewModel: PhotoEditorViewModel())
            .environmentObject(AdManager())
    }
}
