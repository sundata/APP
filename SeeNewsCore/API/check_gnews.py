import urllib.request, socket, feedparser

# Google News RSS 需要特殊 UA
sources = [
    ("Google News 不倫", "https://news.google.com/rss/search?q=%E4%B8%8D%E5%80%AB&hl=ja&gl=JP&ceid=JP:ja"),
    ("Google News 浮気芸能", "https://news.google.com/rss/search?q=%E6%B5%AE%E6%B0%97+%E8%8A%B8%E8%83%BD&hl=ja&gl=JP&ceid=JP:ja"),
]

socket.setdefaulttimeout(10)
for name, url in sources:
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Googlebot/2.1 (+http://www.google.com/bot.html)"
        })
        with urllib.request.urlopen(req, timeout=10) as r:
            raw = r.read(4000).decode("utf-8", errors="ignore")
            print(f"--- {name} ---")
            print(raw[:800])
            print()
    except Exception as e:
        print(f"NG {name}: {e}")
