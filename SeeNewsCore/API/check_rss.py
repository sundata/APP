import urllib.request, socket

sources = [
    # ========== 日本 RSS 源（超稳定） ==========
    # NHK-官方媒体（最稳定）
    ("NHK News総合", "https://www3.nhk.or.jp/rss/news/cat0.xml"),
    ("NHK News社会", "https://www3.nhk.or.jp/rss/news/cat1.xml"),
    ("NHK News政治", "https://www3.nhk.or.jp/rss/news/cat2.xml"),
    
    # Yahoo Japan-覆盖最广
    ("Yahoo Japan頭滑", "https://news.yahoo.co.jp/rss/topics/top-picks.xml"),
    ("Yahoo Japan エンタメ", "https://news.yahoo.co.jp/rss/topics/entertainment.xml"),
    ("Yahoo Japan スポーツ", "https://news.yahoo.co.jp/rss/topics/sports.xml"),
    ("Yahoo Japan ビジネス", "https://news.yahoo.co.jp/rss/topics/business.xml"),
    ("Yahoo Japan 国際", "https://news.yahoo.co.jp/rss/topics/world.xml"),
    
    # ITmedia-科技
    ("ITmedia News", "https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml"),
    
    # ========== 国际 RSS 源 ==========
    ("BBC News", "http://feeds.bbci.co.uk/news/rss.xml"),
    ("NY Times", "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml"),
]

socket.setdefaulttimeout(8)
print("✓ 正在检查所有 RSS 源...\n")
for name, url in sources:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 FeedFetcher"})
        with urllib.request.urlopen(req, timeout=8) as r:
            content = r.read(2000)
            # 支持 RSS (item) 和 Atom (entry) 格式
            ok = b"<item>" in content or b"<entry>" in content
            status = "✓ OK " if ok else "⚠ NO "
            print(f"{status}{name}: HTTP {r.status}")
    except Exception as e:
        print(f"✗ NG {name}: {e}")

print("\n✓ RSS源检查完毕")
