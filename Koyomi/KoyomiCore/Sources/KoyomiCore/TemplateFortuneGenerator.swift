import Foundation

/// ルールエンジン + 校閲済みテンプレートによる占い生成。
/// ネットワークも LLM も使わないため、オフラインでも必ず結果を返せる。
public struct TemplateFortuneGenerator: FortuneGenerating {
    public let contentVersion: Int

    public init(contentVersion: Int = ContentLibrary.contentVersion) {
        self.contentVersion = contentVersion
    }

    public func fortune(for input: FortuneInput) -> DailyFortune {
        let seed = StableSeed(
            dayKey: input.dayKey,
            zodiac: input.zodiac,
            weather: input.weather?.category,
            contentVersion: contentVersion
        )

        // テーマとアクションは「日番号」で回す。
        // これにより、同じ星座でも 7 日以内に同じ主題・同じアクションが出ない。
        let theme = ContentLibrary.theme(for: input.zodiac, rotation: input.dayNumber)
        let action = ContentLibrary.actions.cyclicElement(at: input.dayNumber * 7)

        let flavors = ContentLibrary.zodiacFlavors[input.zodiac] ?? []
        let flavor = flavors.isEmpty ? "" : flavors.element(for: seed.derived("flavor"))
        let closer = ContentLibrary.dailyClosers.element(for: seed.derived("closer"))

        let scores = Scores(seed: seed, weather: input.weather)

        return DailyFortune(
            date: input.dayKey,
            zodiac: input.zodiac,
            overallScore: scores.overall,
            headline: theme.headline,
            overall: "\(theme.body)\(flavor)\(closer)",
            skySign: skySign(for: input, seed: seed),
            love: CategoryFortune(
                score: scores.love,
                text: ContentLibrary.loveTexts.element(for: seed.derived("love"))
            ),
            workStudy: CategoryFortune(
                score: scores.workStudy,
                text: ContentLibrary.workStudyTexts.element(for: seed.derived("work"))
            ),
            beautyHealth: CategoryFortune(
                score: scores.beautyHealth,
                text: ContentLibrary.beautyHealthTexts.element(for: seed.derived("beauty"))
            ),
            social: CategoryFortune(
                score: scores.social,
                text: ContentLibrary.socialTexts.element(for: seed.derived("social"))
            ),
            luckyColor: ContentLibrary.luckyColors.element(for: seed.derived("color")),
            luckyItem: ContentLibrary.luckyItems.element(for: seed.derived("item")),
            luckyTime: luckyTime(seed: seed.derived("time")),
            action: action,
            contentVersion: contentVersion,
            usedWeather: input.weather != nil
        )
    }

    // MARK: - 空からのサイン

    private func skySign(for input: FortuneInput, seed: StableSeed) -> String {
        let base: String
        if let weather = input.weather {
            let hints = ContentLibrary.weatherHints[weather.category] ?? []
            base = hints.isEmpty ? "" : hints.element(for: seed.derived("sky"))
        } else {
            // 天気が取れないときは季節と日付だけを根拠にする（天気は語らない）。
            let hints = ContentLibrary.seasonHints[input.season] ?? []
            base = hints.isEmpty ? "" : hints.element(for: seed.derived("season-sky"))
        }

        guard let moonPhase = input.moonPhase else { return base }
        return "\(base)今夜は\(moonPhase.japaneseName)です。"
    }

    // MARK: - ラッキータイム

    private func luckyTime(seed: StableSeed) -> String {
        let hour = seed.derived("hour").int(in: 7...21)
        let minute = seed.derived("minute").index(upperBound: 12) * 5
        return String(format: "%02d:%02d", hour, minute)
    }

    // MARK: - スコア

    /// スコアはシードから決め、天気で穏やかに補正する。
    /// 悪天候でもスコアが極端に下がらないようにし、下限は 2 とする
    /// （低スコアでも必ず前向きな出口があるように扱う）。
    struct Scores {
        let overall: Int
        let love: Int
        let workStudy: Int
        let beautyHealth: Int
        let social: Int

        init(seed: StableSeed, weather: WeatherSnapshot?) {
            func base(_ salt: String) -> Int {
                seed.derived(salt).int(in: 2...5)
            }

            let modifier = Self.modifier(for: weather)
            func clamp(_ value: Int) -> Int { min(5, max(2, value)) }

            let love = clamp(base("score-love"))
            let workStudy = clamp(base("score-work") + modifier.workStudy)
            let beautyHealth = clamp(base("score-beauty") + modifier.beautyHealth)
            let social = clamp(base("score-social"))
            let average = Double(love + workStudy + beautyHealth + social) / 4.0

            self.love = love
            self.workStudy = workStudy
            self.beautyHealth = beautyHealth
            self.social = social
            self.overall = clamp(Int(average.rounded()))
        }

        /// 天気による補正。行動しやすさ・体の負担だけを穏やかに反映する。
        static func modifier(for weather: WeatherSnapshot?) -> (workStudy: Int, beautyHealth: Int) {
            guard let weather else { return (0, 0) }
            switch weather.category {
            case .clear: return (0, 1)
            case .cloudy, .fog: return (1, 0)
            case .rain: return (1, 0)
            case .snow, .wind: return (0, 0)
            case .thunderstorm: return (0, 0)
            case .extremeHeat, .extremeCold: return (0, -1)
            }
        }
    }
}
