"use client";
// AC-005: watchlist with live prices + remove + star-add from search.
import { useEffect, useState } from "react";
import { api, Quote } from "@/lib/api";
import { connectQuotes } from "@/lib/ws";
import { FreshnessBadge } from "@/components/FreshnessBadge";
import Link from "next/link";

export default function WatchlistPage() {
  const [items, setItems] = useState<Quote[]>([]);
  const [wid, setWid] = useState<string>("");
  const [needLogin, setNeedLogin] = useState(false);
  const token = typeof window !== "undefined" ? localStorage.getItem("sm-token") ?? "" : "";

  useEffect(() => {
    if (!token) { setNeedLogin(true); return; }
    api.watchlists(token).then((r) => {
      const id = r.items[0]?.id;
      if (!id) return;
      setWid(id);
      api.watchlistItems(token, id).then((d) => setItems(d.items as Quote[]));
    }).catch(() => setNeedLogin(true));
  }, [token]);

  useEffect(() => {
    if (!items.length) return;
    const conn = connectQuotes(
      items.map((i) => i.asset_id),
      (quotes) =>
        setItems((prev) =>
          prev.map((p) => {
            const q = quotes.find((x) => x.asset_id === p.asset_id);
            return q ? { ...p, price: q.price, change_pct: q.change_pct } : p;
          })
        )
    );
    return () => conn.close();
  }, [items.length]);

  if (needLogin)
    return <p className="py-10 text-center"><Link href="/login" className="text-blue-600">登录后使用自选</Link></p>;

  return (
    <div className="py-6">
      <table className="w-full text-sm">
        <tbody>
          {items.map((q) => (
            <tr key={q.asset_id} className="border-t">
              <td className="py-2 font-medium"><Link href={`/asset/${q.asset_id}`}>{q.symbol}</Link></td>
              <td className="text-right tabular-nums">{q.price ?? "—"}</td>
              <td className={`text-right tabular-nums ${Number(q.change_pct ?? 0) >= 0 ? "text-up" : "text-down"}`}>
                {q.change_pct ?? "—"}%
              </td>
              <td><FreshnessBadge freshness={q.freshness} /></td>
              <td className="pl-3">
                <button
                  onClick={() => { api.delWatchlistItem(token, wid, q.asset_id); setItems((p) => p.filter((x) => x.asset_id !== q.asset_id)); }}
                  className="text-xs text-neutral-400 hover:text-red-500"
                >移除</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
