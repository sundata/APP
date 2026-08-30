import SwiftUI
import PhotosUI

// MARK: - ホーム画面

struct HomeView: View {
    @StateObject private var editorVM = PhotoEditorViewModel()
    @ObservedObject private var projectStore = ProjectStore.shared
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera        = false
    @State private var navigateToEditor  = false
    // quickSizeSection 用の写真選択ピッカー
    @State private var showPhotosPicker  = false

    // ─── アニメーション状態 ───
    @State private var heroAnimated   = false
    @State private var cardAppeared   = false
    @State private var badgeAppeared  = false
    @State private var sizeAppeared   = false
    @State private var guideAppeared  = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // ── ヒーローヘッダー ──
                            headerSection
                                .padding(.bottom, 32)

                            // ── メインアクション ──
                            startCardSection
                                .padding(.horizontal, 20)
                                .opacity(cardAppeared ? 1 : 0)
                                .offset(y: cardAppeared ? 0 : 28)

                            // ── 機能バッジ ──
                            featureBadgeRow
                                .padding(.horizontal, 20)
                                .padding(.top, 22)
                                .opacity(badgeAppeared ? 1 : 0)
                                .offset(y: badgeAppeared ? 0 : 20)

                            if !projectStore.projects.isEmpty {
                                recentProjectsSection
                                    .padding(.top, 28)
                            }

                            // ── よく使うサイズ ──
                            quickSizeSection
                                .padding(.horizontal, 20)
                                .padding(.top, 30)
                                .opacity(sizeAppeared ? 1 : 0)

                            // ── 使い方ガイド ──
                            howToUseSection
                                .padding(.horizontal, 20)
                                .padding(.top, 30)
                                .opacity(guideAppeared ? 1 : 0)

                            Spacer(minLength: 66)
                        }
                    }
                }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .onAppear {
                print("✅ HomeView.onAppear - UI is visible!")
                runEntranceAnimations()
            }
            // カメラシート
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    HapticFeedback.success()
                    editorVM.setImage(image)
                    showCamera = false
                    navigateToEditor = true
                }
            }
            // quickSizeSection 用の写真選択ピッカー
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            // selectedPhotoItemの変化を監視してエディターに遷移
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            HapticFeedback.success()
                            editorVM.setImage(image.fixedOrientation())
                            selectedPhotoItem = nil
                            navigateToEditor = true
                        }
                    }
                }
            }
            // エディター遷移
            .navigationDestination(isPresented: $navigateToEditor) {
                PhotoEditorView(viewModel: editorVM)
                    .onDisappear {
                        if !navigateToEditor { editorVM.reset() }
                    }
            }
        }
	    }
	}

    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent projects").font(.system(size: 20, weight: .bold))
                Spacer()
                Text("Saved on this device").font(.caption).foregroundColor(Color.appTextSecondary)
            }.padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(projectStore.projects.prefix(6)) { project in
                        Button {
                            if editorVM.restoreProject(project) { navigateToEditor = true }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Group {
                                    if let image = projectStore.thumbnail(for: project.id) { Image(uiImage: image).resizable().scaledToFill() }
                                    else { Color.appSurface.overlay(Image(systemName: "person.crop.rectangle").foregroundColor(.secondary)) }
                                }
                                .frame(width: 112, height: 138).clipped().cornerRadius(12)
                                Text(project.title).font(.caption.weight(.semibold)).lineLimit(1)
                                Text(project.updatedAt, style: .relative).font(.caption2).foregroundColor(.secondary)
                            }.frame(width: 112, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { Button(role: .destructive) { projectStore.delete(project.id) } label: { Label("Delete", systemImage: "trash") } }
                    }
                }.padding(.horizontal, 20)
            }
        }
    }
    // ─────────────────────────────────────
    // MARK: 入場アニメーション
    // ─────────────────────────────────────
    private func runEntranceAnimations() {
        withAnimation(.appSlowSpring.delay(0.1)) { heroAnimated  = true }
        withAnimation(.appSpring.delay(0.25))    { cardAppeared  = true }
        withAnimation(.appSpring.delay(0.38))    { badgeAppeared = true }
        withAnimation(.appSpring.delay(0.50))    { sizeAppeared  = true }
        withAnimation(.appSpring.delay(0.62))    { guideAppeared = true }
    }

    // ─────────────────────────────────────
    // MARK: ヒーローヘッダー
    // ─────────────────────────────────────
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // グラデーション背景
            Color.headerGradient
                .frame(height: 295)
                .ignoresSafeArea(edges: .top)

            // 装飾サークル群
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 230)
                .offset(x: 160, y: -90)
                .blur(radius: 4)
            Circle()
                .fill(Color(hex: "#4AAFFF").opacity(0.10))
                .frame(width: 150)
                .offset(x: -60, y: -10)

            // コンテンツ
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    // ブランドサブタイトル
                    HStack(spacing: 7) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#4AAFFF"))
                        Text("ID PHOTO JAPAN")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#4AAFFF"))
                            .tracking(2.5)
                    }
                    .opacity(heroAnimated ? 1 : 0)
                    .offset(y: heroAnimated ? 0 : 8)

                    // メインタイトル
                    Text("証明写真")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(heroAnimated ? 1 : 0.82, anchor: .leading)
                        .opacity(heroAnimated ? 1 : 0)

                    // サブタイトル
                    Text("プロ品質をスマホで、いつでも")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                        .opacity(heroAnimated ? 1 : 0)
                        .offset(y: heroAnimated ? 0 : 6)

                    // 実績バッジ
                    HStack(spacing: 8) {
                        StatBadge(value: "14+", label: "サイズ対応")
                        StatBadge(value: "AI", label: "背景除去")
                        StatBadge(value: "1分", label: "で完成")
                    }
                    .padding(.top, 4)
                    .opacity(heroAnimated ? 1 : 0)
                    .offset(y: heroAnimated ? 0 : 10)
                }

                Spacer()

                // アプリアイコン風バッジ
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )

                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .scaleEffect(heroAnimated ? 1 : 0.65)
                .opacity(heroAnimated ? 1 : 0)
                .rotationEffect(.degrees(heroAnimated ? 0 : -8))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // ─────────────────────────────────────
    // MARK: メインアクションカード
    // ─────────────────────────────────────
    private var startCardSection: some View {
        VStack(spacing: 12) {
            // カメラ撮影ボタン（メイン）
            Button {
                HapticFeedback.medium()
                showCamera = true
            } label: {
                ActionRow(
                    icon: "camera.fill",
                    iconGradient: [Color(hex: "#2C7EC8"), Color(hex: "#1A4A7A")],
                    iconShadowColor: Color(hex: "#2C7EC8"),
                    title: "カメラで撮影",
                    badge: "おすすめ",
                    badgeColor: Color(hex: "#FF6B35"),
                    subtitle: "その場で正面写真を撮影して作成"
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // フォトライブラリ選択ボタン
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ActionRow(
                    icon: "photo.on.rectangle.angled",
                    iconGradient: [Color(hex: "#30B96A"), Color(hex: "#1A7A45")],
                    iconShadowColor: Color(hex: "#30B96A"),
                    title: "写真を選択",
                    badge: nil,
                    badgeColor: .clear,
                    subtitle: "フォトライブラリから既存の写真を選ぶ"
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { HapticFeedback.medium() })
        }
    }

    // ─────────────────────────────────────
    // MARK: 機能バッジ行
    // ─────────────────────────────────────
    private var featureBadgeRow: some View {
        HStack(spacing: 0) {
            FeatureBadge(icon: "wand.and.stars",       label: "AI背景除去",   color: Color(hex: "#9B59B6"))
            FeatureBadge(icon: "face.smiling.inverse", label: "美肌補正",     color: Color(hex: "#E67E22"))
            FeatureBadge(icon: "printer.fill",         label: "L判印刷",      color: Color(hex: "#2980B9"))
            FeatureBadge(icon: "checkmark.seal.fill",  label: "14サイズ",     color: Color(hex: "#27AE60"))
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
        )
    }

    // ─────────────────────────────────────
    // MARK: よく使うサイズ
    // ─────────────────────────────────────
    private var quickSizeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "よく使うサイズ", subtitle: "タップでそのサイズを選んで開始")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(IDPhotoSize.popularSizes.enumerated()), id: \.element.id) { idx, size in
                    QuickSizeCard(size: size, delay: Double(idx) * 0.07) {
                        HapticFeedback.light()
                        editorVM.reset()
                        editorVM.selectSize(size)
                        showPhotosPicker = true
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────
    // MARK: 使い方ガイド
    // ─────────────────────────────────────
    private var howToUseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "かんたん3ステップ", subtitle: "最短1分で証明写真が完成")

            VStack(spacing: 0) {
                ForEach(HowToStep.steps.indices, id: \.self) { i in
                    HowToStepRow(step: HowToStep.steps[i], isLast: i == HowToStep.steps.count - 1)
                }
            }
            .background(Color.appSurface)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
        }
        .padding(.bottom, 8)
    }
}

// ─────────────────────────────────────
// MARK: - アクションロウ（カメラ・ライブラリ）
// ─────────────────────────────────────

private struct ActionRow: View {
    let icon: String
    let iconGradient: [Color]
    let iconShadowColor: Color
    let title: String
    let badge: String?
    let badgeColor: Color
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            // アイコンサークル
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: iconGradient,
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: iconShadowColor.opacity(0.38), radius: 8, y: 3)
                Image(systemName: icon)
                    .font(.system(size: 21))
                    .foregroundColor(.white)
            }

            // テキスト
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                    if let badge {
                        BadgeLabel(text: badge, color: badgeColor)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.appTextSecondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [iconGradient.first?.opacity(0.25) ?? .clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .tapHighlight(cornerRadius: 18)
    }
}

// ─────────────────────────────────────
// MARK: - ヒーロースタッツバッジ
// ─────────────────────────────────────

private struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.14))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// ─────────────────────────────────────
// MARK: - 機能バッジ
// ─────────────────────────────────────

struct FeatureBadge: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 60)
        }
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────
// MARK: - よく使うサイズカード
// ─────────────────────────────────────

struct QuickSizeCard: View {
    let size: IDPhotoSize
    var delay: Double = 0
    let onTap: () -> Void

    @State private var appeared = false

    private var previewW: CGFloat { max(22, CGFloat(size.widthMM) * 0.82) }
    private var previewH: CGFloat { max(28, CGFloat(size.heightMM) * 0.82) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 11) {
                // ミニ比率プレビュー
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: "#EBF4FF"))
                        .frame(width: previewW, height: previewH)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1.2)
                        )
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appPrimary.opacity(0.45))
                }
                .frame(width: 42, height: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text(size.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(1)
                    Text("\(Int(size.widthMM)) × \(Int(size.heightMM)) mm")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appPrimary)
                    Text(size.category.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appTextSecondary.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.appSurface)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.055), radius: 8, x: 0, y: 3)
            .tapHighlight(cornerRadius: 14)
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .onAppear {
            withAnimation(.appSpring.delay(0.42 + delay)) {
                appeared = true
            }
        }
    }
}

// ─────────────────────────────────────
// MARK: - 使い方ステップ
// ─────────────────────────────────────

struct HowToStep {
    let number: Int
    let icon: String
    let title: String
    let detail: String
    let color: Color

    static let steps: [HowToStep] = [
        HowToStep(number: 1, icon: "camera.viewfinder",
                  title: "写真を用意する",
                  detail: "カメラ撮影 or フォトライブラリから選択",
                  color: Color(hex: "#2C7EC8")),
        HowToStep(number: 2, icon: "slider.horizontal.3",
                  title: "サイズ・背景を調整する",
                  detail: "14種のサイズ、AI背景除去、美肌補正対応",
                  color: Color(hex: "#9B59B6")),
        HowToStep(number: 3, icon: "square.and.arrow.down.fill",
                  title: "保存・印刷する",
                  detail: "フォトライブラリ保存 / L判プリントレイアウト作成",
                  color: Color(hex: "#27AE60")),
    ]
}

struct HowToStepRow: View {
    let step: HowToStep
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(step.color.opacity(0.13))
                        .frame(width: 42, height: 42)
                    Image(systemName: step.icon)
                        .font(.system(size: 17))
                        .foregroundColor(step.color)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.appDivider)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("STEP \(step.number)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(step.color)
                    Text(step.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                }
                Text(step.detail)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 10)
            .padding(.bottom, isLast ? 18 : 8)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, step.number == 1 ? 18 : 0)
    }
}

// ─────────────────────────────────────
// MARK: - カメラビュー
// ─────────────────────────────────────

struct CameraPickerView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType        = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice      = .front
        picker.allowsEditing     = false
        picker.delegate          = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.originalImage] as? UIImage)?.fixedOrientation()
                     ?? (info[.editedImage]   as? UIImage)?.fixedOrientation()
            if let image { onCapture(image) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
