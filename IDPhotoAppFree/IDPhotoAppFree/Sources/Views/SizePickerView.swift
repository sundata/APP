import SwiftUI

// MARK: - 証明写真サイズ選択画面（フルリニューアル）
struct SizePickerView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @State private var selectedCategory: IDPhotoSize.SizeCategory? = nil
    @State private var searchText = ""
    @State private var showProUpgrade = false

    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.appSurface)

            // 有料版への誘導バナー
            if AppConfig.isFreeVersion {
                proBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

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
                            isPopular: isPopular(size),
                            isRestricted: size.isPro
                        ) {
                            handleSizeSelection(size)
                        }
                        .padding(.horizontal, 16)
                    }

                    if filteredSizes.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeView()
        }
    }

    // MARK: - サイズ選択処理
    private func handleSizeSelection(_ size: IDPhotoSize) {
        if AppConfig.isFreeVersion && size.isPro {
            // Pro Size 選択時は有料版への誘導を表示
            HapticFeedback.warning()
            showProUpgrade = true
        } else {
            HapticFeedback.selection()
            withAnimation(.appQuickSpring) {
                viewModel.selectSize(size)
            }
        }
    }

    // MARK: - 有料版誘導バナー
    private var proBanner: some View {
        Button {
            showProUpgrade = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                Text("有料版で全てのサイズが使用可能")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
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

    private func isPopular(_ size: IDPhotoSize) -> Bool {
        ["passport_jp", "license_jp", "mynumber", "resume_l", "resume_s"].contains(size.id)
    }

    private func categoryIcon(_ cat: IDPhotoSize.SizeCategory) -> String {
        switch cat {
        case .passport:   return "airplane"
        case .license:    return "car.fill"
        case .mynumber:   return "person.crop.square"
        case .employment: return "briefcase.fill"
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
    let isRestricted: Bool
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

                        // Pro ロックアイコン
                        if isRestricted {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("\(Int(size.widthMM)) × \(Int(size.heightMM)) mm")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isRestricted ? .orange : Color.appPrimary)
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
                    if isRestricted {
                        // 有料版ロック表示
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    } else {
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

// ProUpgradeView と FeatureRow は ProUpgradeView.swift に移動しました
