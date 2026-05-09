import Foundation
import UIKit

// MARK: - 模拟数据提供器（开发/测试用）
class MockDataProvider {
    
    static func createMockArticles() -> [NewsArticle] {
        let sources = [
            Source(name: "週刊女性PRIME", logoURL: nil, website: URL(string: "https://jprime.jp")!),
            Source(name: "女性自身", logoURL: nil, website: URL(string: "https://jisin.jp")!),
            Source(name: "フライデー", logoURL: nil, website: URL(string: "https://friday.kodansha.co.jp")!),
            Source(name: "FLASH", logoURL: nil, website: URL(string: "https://flash.shueisha.co.jp")!),
            Source(name: "NEWS ポストセブン", logoURL: nil, website: URL(string: "https://www.news-postseven.com")!)
        ]
        
        return [
            NewsArticle(
                title: "人気俳優と元アイドルの熱愛報道に事務所が異例の即日否定",
                summary: "週刊誌がスクープしたお忍びデート報道に対し、所属事務所は「食事を共にしただけ」と即座に否定。ネット上では「否定が早すぎる」「逆に怪しい」と様々な声が飛び交っている。",
                content: nil,
                source: sources[0],
                author: "芸能デスク",
                publishedAt: Date().addingTimeInterval(-1800),
                url: URL(string: "https://jprime.jp/articles/-/48292")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800"),
                category: .celebrity,
                isRead: false,
                isBookmarked: false
            ),
            NewsArticle(
                title: "グラビアアイドルが初の映画主演「ただのきれいな人だと思われたくない」",
                summary: "グラビア界のトップランナーが映画初主演を果たし、演技派としての転身を宣言。「見た目だけで判断されるのは悔しい」と本音を吐露し、同業者からも応援の声が相次ぐ。",
                content: nil,
                source: sources[1],
                author: "エンタメ班",
                publishedAt: Date().addingTimeInterval(-3600),
                url: URL(string: "https://jisin.jp/entertainment/873852")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=800"),
                category: .celebrity,
                isRead: false,
                isBookmarked: true
            ),
            NewsArticle(
                title: "国民的番組の司会者、不倫報道で番組降板か　各局が対応協議",
                summary: "長年愛されたバラエティ番組の司会者が週刊誌に不倫を報じられ、所属局は緊急会議を開催。視聴者からは「番組は好きでも司会者は変えてほしい」と厳しい意見も。",
                content: nil,
                source: sources[2],
                author: "芸能取材班",
                publishedAt: Date().addingTimeInterval(-5400),
                url: URL(string: "https://friday.kodansha.co.jp/article/384921")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800"),
                category: .trending,
                isRead: false,
                isBookmarked: false
            ),
            NewsArticle(
                title: "大谷翔平が今季20号ホームラン　試合後のインタビューで妻への愛語る",
                summary: "ドジャースの大谷翔平が敵地で今季20号を放ちリーグ首位に並んだ。試合後のインタビューでは「妻が一番のサポーター」と笑顔を見せ、ファンの心を撃ち抜いた。",
                content: nil,
                source: sources[4],
                author: "スポーツ部",
                publishedAt: Date().addingTimeInterval(-7200),
                url: URL(string: "https://www.news-postseven.com/archives/20250430_2348756.html")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1461896836934-bd45ba24a0b6?w=800"),
                category: .sports,
                isRead: true,
                isBookmarked: false
            ),
            NewsArticle(
                title: "美女アナウンサーが突然退社「次のステージに進みたい」真意は",
                summary: "局の看板アナが突然の退社を発表。SNSでは「誰かと結婚？」「独立してフリーに？」と憶測が飛び交うが、本人は「自分の可能性を広げたい」と前向きな理由を強調。",
                content: nil,
                source: sources[3],
                author: "メディア担当",
                publishedAt: Date().addingTimeInterval(-9000),
                url: URL(string: "https://flash.shueisha.co.jp/articles/-/21573")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800"),
                category: .celebrity,
                isRead: false,
                isBookmarked: true
            ),
            NewsArticle(
                title: "与党大物議員の愛人騒動、野党が「政治とカネと女」の三重苦として追及",
                summary: "与党の有力議員が公金流用の疑いで愛人に毎月100万円を渡していた疑惑が浮上。野党は来週の予算委員会で徹底追及の構えを見せ、政界に波紋が広がっている。",
                content: nil,
                source: sources[0],
                author: "政治部",
                publishedAt: Date().addingTimeInterval(-10800),
                url: URL(string: "https://jprime.jp/articles/-/48288")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?w=800"),
                category: .politician,
                isRead: false,
                isBookmarked: false
            ),
            NewsArticle(
                title: "映画『名探偵コナン』最新作が興収100億円突破　海外でも大ヒット",
                summary: "公開3週目で累計興行収入100億円を突破。シリーズ最高記録を更新中で、アジア各国でも連日満員御礼。日本のアニメの底力を改めて見せつける結果に。",
                content: nil,
                source: sources[1],
                author: "エンタメ担当",
                publishedAt: Date().addingTimeInterval(-12600),
                url: URL(string: "https://jisin.jp/entertainment/873841")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800"),
                category: .celebrity,
                isRead: true,
                isBookmarked: false
            ),
            NewsArticle(
                title: "共演がきっかけのW不倫、双方の家庭が崩壊の危機に直面",
                summary: "ドラマで共演した俳優と女優が互いの配偶者を裏切り不倫関係に。双方に子供がいるため影響は大きく、所属事務所は「事実確認中」とするも対応に追われている。",
                content: nil,
                source: sources[2],
                author: "芸能取材班",
                publishedAt: Date().addingTimeInterval(-14400),
                url: URL(string: "https://friday.kodansha.co.jp/article/384915")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1517960413843-0aee8e2b3285?w=800"),
                category: .trending,
                isRead: false,
                isBookmarked: false
            ),
            NewsArticle(
                title: "女性タレントの盗撮被害、犯人は元交際相手　デジタルタトゥーの恐怖",
                summary: "バラエティで活躍する女性タレントが自宅での盗撮被害を告白。警察の捜査で犯人が元カレと判明し、画像が拡散される前に被害を食い止めた。SNS時代の性的被害の恐ろしさとして話題に。",
                content: nil,
                source: sources[4],
                author: "社会部",
                publishedAt: Date().addingTimeInterval(-16200),
                url: URL(string: "https://www.news-postseven.com/archives/20250430_2348741.html")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=800"),
                category: .trending,
                isRead: false,
                isBookmarked: true
            ),
            NewsArticle(
                title: "日経平均が4万円台回復　市場関係者は「芸能スキャンダルより経済を見ろ」と呆れ",
                summary: "東京市場で日経平均が4万円台を回復したが、SNSのトレンドは芸能不倫一色。「経済の大きな動きよりスキャンダルの方が拡散される時代」と市場関係者が嘆く一幕も。",
                content: nil,
                source: sources[3],
                author: "経済部",
                publishedAt: Date().addingTimeInterval(-18000),
                url: URL(string: "https://flash.shueisha.co.jp/articles/-/21568")!,
                imageURL: URL(string: "https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=800"),
                category: .business,
                isRead: false,
                isBookmarked: false
            )
        ]
    }
}
