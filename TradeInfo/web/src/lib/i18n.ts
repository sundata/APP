// SimpleMarket i18n (§27): zh-CN (default), en, ja.
export type Locale = "zh" | "en" | "ja";

const dicts: Record<Locale, Record<string, string>> = {
  zh: {
    home: "首页", markets: "行情", watchlist: "自选", news: "新闻", calendar: "日历",
    search: "搜索", login: "登录", settings: "设置", logout: "退出",
    today: "今日", important: "重要", live: "实时", delayed: "延迟",
    stale: "已过期", closed: "休市", no_data: "无数据",
    price: "价格", change: "涨跌", high: "最高", low: "最低",
    add_to_watchlist: "加入自选", create_alert: "创建提醒",
  },
  en: {
    home: "Home", markets: "Markets", watchlist: "Watchlist", news: "News", calendar: "Calendar",
    search: "Search", login: "Sign in", settings: "Settings", logout: "Sign out",
    today: "Today", important: "Important", live: "Live", delayed: "Delayed",
    stale: "Stale", closed: "Closed", no_data: "No data",
    price: "Price", change: "Change", high: "High", low: "Low",
    add_to_watchlist: "Add to watchlist", create_alert: "Create alert",
  },
  ja: {
    home: "ホーム", markets: "相場", watchlist: "ウォッチ", news: "ニュース", calendar: "カレンダー",
    search: "検索", login: "ログイン", settings: "設定", logout: "ログアウト",
    today: "今日", important: "重要", live: "リアルタイム", delayed: "遅延",
    stale: "古い", closed: "休場", no_data: "データなし",
    price: "価格", change: "変動", high: "高値", low: "安値",
    add_to_watchlist: "ウォッチに追加", create_alert: "アラート作成",
  },
};

export function t(locale: Locale, key: string): string {
  return dicts[locale][key] ?? dicts.en[key] ?? key;
}
export const LOCALES: Locale[] = ["zh", "en", "ja"];
