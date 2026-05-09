import SwiftUI

// MARK: - 証明写真サイズ選択画面（フルリニューアル）
struct SizePickerView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var selectedCategory: IDPhotoSize.SizeCategory? = nil
    @State private var searchText = ""

    // ── カスタムサイズ入力状態 ──
    @State private var customWidthText: String = ""
    @State private var customHeightText: String = ""
    @State private var customNameText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.appSurface)

            // よく使われるサイズ（横スクロール）
            if searchText.isEmpty && selectedCategory == nil {
                popularSection
                    .padding(.top, 4)
            }

            // カテゴリタブ
            categoryTabBar

            // サイズリスト
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10, pinnedViews: []) {
                    ForEach(filteredSizes) { size in
                        SizeCard(
                            size: size,
                            isSelected: viewModel.editState.selectedSize.id == size.id,
                            isPopular: isPopular(size)
                        ) {
                            HapticFeedback.selection()
                            withAnimation(.appQuickSpring) {
                                viewModel.selectSize(size)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if selectedCategory == .custom {
                        customSizeInputForm
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    if filteredSizes.isEmpty && selectedCategory != .custom {
                        emptyState
                            .padding(.top, 60)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - 検索バー
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(Color.appTextSecondary)
            TextField("サイズを検索…", text: $searchText)
                .font(.system(size: 14))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.appDivider.opacity(0.3))
        .cornerRadius(10)
    }

    // MARK: - よく使われるサイズ
    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("よく使われるサイズ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(IDPhotoSize.popularSizes) { size in
                        PopularSizeChip(
                            size: size,
                            isSelected: viewModel.editState.selectedSize.id == size.id
                        ) {
                            HapticFeedback.selection()
                            withAnimation(.appQuickSpring) {
                                viewModel.selectSize(size)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            Divider()
        }
        .background(Color.appSurface)
    }

    // MARK: - カテゴリタブ
    private var categoryTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 「全て」タブ
                Button {
                    withAnimation(.appEase) {
                        selectedCategory = nil
                    }
                } label: {
                    Text("全て")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectedCategory == nil ? .white : Color.appTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == nil ? Color.appPrimary : Color.appDivider.opacity(0.5)
                        )
                        .cornerRadius(20)
                }

                ForEach(IDPhotoSize.SizeCategory.allCases, id: \.self) { cat in
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.appEase) {
                            selectedCategory = cat
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: categoryIcon(cat))
                                .font(.system(size: 11))
                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(selectedCategory == cat ? .white : Color.appTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == cat ?
                                Color.appPrimary : Color.appDivider.opacity(0.5)
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.appSurface)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - 空状態
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Color.appTextSecondary.opacity(0.5))
            Text("「\(searchText)」に一致するサイズが見つかりません")
                .font(.system(size: 14))
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - フィルタリング
    private var filteredSizes: [IDPhotoSize] {
        var sizes = IDPhotoSize.allSizes
        if let cat = selectedCategory {
            sizes = sizes.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            sizes = sizes.filter {
                $0.name.lowercased().contains(q) ||
                $0.description.lowercased().contains(q)
            }
        }
        return sizes
    }

    // ── カスタムサイズ入力フォーム ──
    private var customSizeInputForm: some View {
        VStack(spacing: 16) {
            // ヘッダー
            HStack {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20))
                    .foregroundColor(Color.appPrimary)
                Text("カスタムサイズを入力")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                if viewModel.editState.usingCustomSize {
                    Text("選択中")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                }
            }

            // 名前入力
            VStack(alignment: .leading, spacing: 6) {
                Text("サイズ名（任意）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                TextField("例：カスタムサイズ", text: $customNameText)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.appDivider.opacity(0.3))
                    .cornerRadius(10)
            }

            // 幅・高さ入力
            HStack(spacing: 16) {
                // 幅
                VStack(alignment: .leading, spacing: 6) {
                    Text("幅（mm）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                    HStack(spacing: 6) {
                        TextField("35", text: $customWidthText)
                            .font(.system(size: 16, weight: .medium))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(Color.appDivider.opacity(0.3))
                            .cornerRadius(10)
                        Text("mm")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }

                Text("×")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)
                    .padding(.top, 20)

                // 高さ
                VStack(alignment: .leading, spacing: 6) {
                    Text("高さ（mm）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                    HStack(spacing: 6) {
                        TextField("45", text: $customHeightText)
                            .font(.system(size: 16, weight: .medium))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(Color.appDivider.opacity(0.3))
                            .cornerRadius(10)
                        Text("mm")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
            }

            // 適用ボタン
            Button {
                HapticFeedback.medium()
                applyCustomSize()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text("このサイズを適用")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appPrimary)
                )
            }
            .disabled(!isCustomInputValid)

            // 共通サイズプリセット
            VStack(alignment: .leading, spacing: 10) {
                Text("よく使われるサイズ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(commonCustomSizes, id: \.name) { preset in
                        Button {
                            customWidthText  = String(Int(preset.widthMM))
                            customHeightText = String(Int(preset.heightMM))
                            customNameText   = preset.name
                            HapticFeedback.selection()
                        } label: {
                            Text("\(preset.name)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.appPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.appPrimary.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appSurface)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
        .onAppear {
            // 既存のカスタムサイズを表示
            if let cs = viewModel.editState.customSize {
                customWidthText  = String(Int(cs.widthMM))
                customHeightText = String(Int(cs.heightMM))
                customNameText   = cs.name == "カスタムサイズ" ? "" : cs.name
            }
        }
    }

    /// カスタムサイズを適用
    private func applyCustomSize() {
        guard let w = Double(customWidthText),
              let h = Double(customHeightText),
              w > 0, h > 0, w <= 200, h <= 300 else { return }
        let name = customNameText.isEmpty ? "カスタムサイズ" : customNameText
        HapticFeedback.medium()
        viewModel.selectCustomSize(width: w, height: h, name: name)
    }

    private var isCustomInputValid: Bool {
        guard let w = Double(customWidthText),
              let h = Double(customHeightText) else { return false }
        return w > 0 && h > 0 && w <= 200 && h <= 300
    }

    private var commonCustomSizes: [IDPhotoSize.CustomSizeInfo] {
        [
            IDPhotoSize.CustomSizeInfo(widthMM: 25, heightMM: 35, name: "1インチ（中国）"),
            IDPhotoSize.CustomSizeInfo(widthMM: 35, heightMM: 53, name: "2インチ（中国）"),
            IDPhotoSize.CustomSizeInfo(widthMM: 40, heightMM: 60, name: "4×6cm"),
            IDPhotoSize.CustomSizeInfo(widthMM: 45, heightMM: 55, name: "45×55mm"),
            IDPhotoSize.CustomSizeInfo(widthMM: 50, heightMM: 50, name: "50×50mm"),
            IDPhotoSize.CustomSizeInfo(widthMM: 60, heightMM: 40, name: "60×40mm"),
        ]
    }

    private func isPopular(_ size: IDPhotoSize) -> Bool {
        ["passport_jp", "visa_us", "visa_eu", "visa_cn",
         "exam_standard",
         "mynumber", "resume_l", "resume_s",
         "us_2x3", "cn_1寸", "cn_2寸"].contains(size.id)
    }

    private func categoryIcon(_ cat: IDPhotoSize.SizeCategory) -> String {
        switch cat {
        case .passport:   return "airplane"
        case .license:    return "car.fill"
        case .mynumber:   return "person.crop.square"
        case .employment: return "briefcase.fill"
        case .custom:     return "square.and.pencil"
        case .other:      return "ellipsis.circle.fill"
        }
    }
}

// MARK: - 人気サイズチップ
struct PopularSizeChip: View {
    let size: IDPhotoSize
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // 縮尺比率プレビュー
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.appPrimary.opacity(0.15) : Color.appDivider.opacity(0.5))
                        .frame(
                            width: max(24, CGFloat(size.widthMM) * 0.85),
                            height: max(30, CGFloat(size.heightMM) * 0.85)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.appPrimary : Color.appDivider, lineWidth: 1.5)
                        )

                    Text("\(Int(size.widthMM))×\(Int(size.heightMM))")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isSelected ? Color.appPrimary : Color.appTextSecondary)
                }
                .frame(width: 46, height: 54, alignment: .center)

                Text(size.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? Color.appPrimary : Color.appTextPrimary)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.appPrimary.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.appPrimary.opacity(0.4) : Color.appDivider.opacity(0.4),
                                    lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - サイズカード（リニューアル）
struct SizeCard: View {
    let size: IDPhotoSize
    let isSelected: Bool
    let isPopular: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // サイズ比率プレビュー
                sizePreview

                // 情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(size.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.appTextPrimary)

                        if isPopular {
                            Text("人気")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.appPrimary)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("\(Int(size.widthMM)) × \(Int(size.heightMM)) mm")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.appPrimary)
                        Text("·")
                            .foregroundColor(Color.appTextSecondary)
                        Text("\(size.widthPx)×\(size.heightPx)px")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }

                    Text(size.description)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // 選択インジケーター
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.appPrimary : Color.appDivider, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.appSurface)
                    .shadow(
                        color: isSelected ? Color.appPrimary.opacity(0.18) : .black.opacity(0.05),
                        radius: isSelected ? 8 : 4, x: 0, y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.appPrimary.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
    }

    private var sizePreview: some View {
        ZStack {
            // 縮尺を維持した比率プレビュー
            let scale: CGFloat = 1.1
            let w = CGFloat(size.widthMM) * scale
            let h = CGFloat(size.heightMM) * scale

            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.appPrimary.opacity(0.12) : Color.appDivider.opacity(0.4))
                .frame(width: w, height: h)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.appPrimary : Color.appDivider, lineWidth: 1.5)
                )
        }
        .frame(width: 56, height: 72, alignment: .center)
    }
}

#Preview {
    NavigationStack {
        SizePickerView(viewModel: PhotoEditorViewModel())
    }
}
