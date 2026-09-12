// §7.2 Home: default watchlist quotes + important news + today calendar + movers.
import { api } from "@/lib/api";
import { QuoteTable } from "@/components/QuoteTable";
import Link from "next/link";

export default async function Home() {
  const [quotes, news, events] = await Promise.all([
    api.quotes("?limit=12").catch(() => ({ items: [], next_cursor: null })),
    api.news("?importance=important&limit=5").catch(() => ({ items: [], next_cursor: null })),
    api.calendar("?importance=high").catch(() => ({ items: [], next_cursor: null })),
  ]);
  return (
    <div className="grid gap-8 py-6">
      <section>
        <h2 className="mb-2 text-sm font-semibold text-neutral-500">自选行情</h2>
        <QuoteTable items={quotes.items} />
      </section>
      <section>
        <h2 className="mb-2 text-sm font-semibold text-neutral-500">涨跌榜</h2>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <h3 className="mb-1 text-xs text-up">涨幅</h3>
            {[...quotes.items]
              .filter((q) => Number(q.change_pct ?? 0) > 0)
              .sort((a, b) => Number(b.change_pct) - Number(a.change_pct))
              .slice(0, 5)
              .map((q) => (
                <div key={q.asset_id} className="flex justify-between">
                  <span>{q.symbol}</span>
                  <span className="tabular-nums text-up">+{q.change_pct}%</span>
                </div>
              ))}
          </div>
          <div>
            <h3 className="mb-1 text-xs text-down">跌幅</h3>
            {[...quotes.items]
              .filter((q) => Number(q.change_pct ?? 0) < 0)
              .sort((a, b) => Number(a.change_pct) - Number(b.change_pct))
              .slice(0, 5)
              .map((q) => (
                <div key={q.asset_id} className="flex justify-between">
                  <span>{q.symbol}</span>
                  <span className="tabular-nums text-down">{q.change_pct}%</span>
                </div>
              ))}
          </div>
        </div>
      </section>
      <section>
        <h2 className="mb-2 text-sm font-semibold text-neutral-500">重要新闻</h2>
        <ul className="space-y-2 text-sm">
          {news.items.map((n) => (
            <li key={n.id}>
              <a href={n.source_url} target="_blank" className="hover:underline">{n.title}</a>
              <span className="ml-2 text-xs text-neutral-400">{n.source}</span>
            </li>
          ))}
        </ul>
      </section>
      <section>
        <h2 className="mb-2 text-sm font-semibold text-neutral-500">今日高影响事件</h2>
        <ul className="space-y-1 text-sm">
          {events.items.slice(0, 5).map((e) => (
            <li key={e.id}>{e.event_time_utc.slice(11, 16)} UTC · {e.name}</li>
          ))}
        </ul>
        <Link href="/calendar" className="text-xs text-blue-600">全部 →</Link>
      </section>
    </div>
  );
}
