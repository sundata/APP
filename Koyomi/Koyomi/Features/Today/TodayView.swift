import SwiftUI
import KoyomiCore

struct TodayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: TodayViewModel
    @State private var showShareCard = false
    @State private var showCityPicker = false

    init(viewModel: TodayViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            NightSkyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                    header
                    if viewModel.state == .loading && viewModel.fortune == nil {
                        SkeletonCard(lines: 4)
                        SkeletonCard(lines: 2)
                    } else if let fortune = viewModel.fortune {
                        cautionBanner
                        mainCard(fortune)
                        skySignCard(fortune)
                        categoryGrid(fortune)
                        luckyCard(fortune)
                        actionCard(fortune)
                        buttons
                        Text(fortune.disclaimer)
                            .font(KoyomiTheme.captionFont)
                            .foregroundStyle(KoyomiTheme.secondaryText(colorScheme))
                    } else {
                        SkeletonCard(lines: 3)
                    }
                }
                .padding(KoyomiTheme.Spacing.m)
            }
            .refreshable { await viewModel.refreshWeather() }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showShareCard) {
            if let content = viewModel.shareCardContent {
                ShareCardView(content: content)
            }
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerView { city in
                showCityPicker = false
                Task { await viewModel.selectCity(city) }
            }
        }
    }

    // MARK: - パーツ

    private var header: some View {
        VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
            Text(viewModel.displayDate)
                .font(KoyomiTheme.titleFont)
                .foregroundStyle(KoyomiTheme.moonBeige)
            HStack(spacing: KoyomiTheme.Spacing.s) {
                if let snapshot = viewModel.weather.snapshot {
                    Image(systemName: snapshot.category.symbolName)
                    Text("\(viewModel.cityName) \(snapshot.temperatureText)")
                    Text(snapshot.highLowText)
                        .font(KoyomiTheme.captionFont)
                } else {
                    Image(systemName: "cloud.moon")
                    Text(viewModel.cityName)
                }
            }
            .font(KoyomiTheme.bodyFont)
            .foregroundStyle(KoyomiTheme.moonBeige.opacity(0.9))

            if let notice = viewModel.weatherNotice {
                Text(notice)
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(KoyomiTheme.moonBeige.opacity(0.8))
            }
            if viewModel.needsCityChoice {
                Button("都市を選ぶ") { showCityPicker = true }
                    .font(KoyomiTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(KoyomiTheme.moonBeige)
                    .frame(minHeight: KoyomiTheme.minimumTapTarget, alignment: .leading)
                    .accessibilityIdentifier("today.selectCity")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 荒天時は占いで危険をぼかさず、客観的な注意を先に見せる。
    @ViewBuilder
    private var cautionBanner: some View {
        if let snapshot = viewModel.weather.snapshot, snapshot.category.deservesCaution {
            GlassCard {
                HStack(spacing: KoyomiTheme.Spacing.s) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("\(snapshot.category.japaneseName)の予報です。最新の気象情報を確認して、無理のない行動を選んでください。")
                        .font(KoyomiTheme.bodyFont)
                }
                .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
            }
        }
    }

    private func mainCard(_ fortune: DailyFortune) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                Text("今日の運勢")
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(KoyomiTheme.secondaryText(colorScheme))
                Text(fortune.headline)
                    .font(KoyomiTheme.headlineFont)
                    .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
                    .accessibilityIdentifier("today.headline")
                ScoreStars(score: fortune.overallScore, size: 20)
                Text(fortune.overall)
                    .font(KoyomiTheme.bodyFont)
                    .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func skySignCard(_ fortune: DailyFortune) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
                Text("空からのサイン")
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(KoyomiTheme.secondaryText(colorScheme))
                Text(fortune.skySign)
                    .font(KoyomiTheme.bodyFont)
                    .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func categoryGrid(_ fortune: DailyFortune) -> some View {
        VStack(spacing: KoyomiTheme.Spacing.s) {
            categoryCard("恋愛運", fortune.love)
            categoryCard("仕事・勉強運", fortune.workStudy)
            categoryCard("美容・健康運", fortune.beautyHealth)
            categoryCard("対人運", fortune.social)
        }
    }

    private func categoryCard(_ title: String, _ value: CategoryFortune) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
                HStack {
                    Text(title)
                        .font(KoyomiTheme.bodyFont.weight(.semibold))
                    Spacer()
                    ScoreStars(score: value.score)
                }
                Text(value.text)
                    .font(KoyomiTheme.bodyFont)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private func luckyCard(_ fortune: DailyFortune) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                HStack(spacing: KoyomiTheme.Spacing.s) {
                    Circle()
                        .fill(KoyomiTheme.color(hex: fortune.luckyColor.hex))
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                    Text("ラッキーカラー：\(fortune.luckyColor.name)")
                }
                Text("ラッキーアイテム：\(fortune.luckyItem)")
                Text("ラッキータイム：\(fortune.luckyTime)")
            }
            .font(KoyomiTheme.bodyFont)
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private func actionCard(_ fortune: DailyFortune) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
                Text("今日の小さなアクション")
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(KoyomiTheme.secondaryText(colorScheme))
                Text(fortune.action)
                    .font(KoyomiTheme.bodyFont.weight(.semibold))
                    .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: KoyomiTheme.Spacing.s) {
            Button {
                viewModel.toggleFavorite()
            } label: {
                Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                    .frame(width: KoyomiTheme.minimumTapTarget, height: KoyomiTheme.minimumTapTarget)
                    .foregroundStyle(KoyomiTheme.moonBeige)
                    .background(
                        RoundedRectangle(cornerRadius: KoyomiTheme.Radius.small, style: .continuous)
                            .fill(KoyomiTheme.nightSky)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(viewModel.isFavorite ? "お気に入りから外す" : "お気に入りに追加"))

            KoyomiPrimaryButton(title: "シェアカードをつくる") { showShareCard = true }
                .accessibilityIdentifier("today.share")
        }
    }
}
