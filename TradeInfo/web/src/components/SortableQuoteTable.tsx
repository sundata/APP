"use client";
// §8 sort/filter/favorite on the markets table.
import { useMemo, useState } from "react";
import Link from "next/link";
import { Quote } from "@/lib/api";
import { FreshnessBadge } from "./FreshnessBadge";

type Key = "symbol" | "price" | "change_pct";

export function SortableQuoteTable({ items }: { items: Quote[] }) {
  const [sort, setSort] = useState<{ key: Key; asc: boolean }>({ key: "change_pct", asc: false });
  const [fav, setFav] = useState<Set<string>>(() => {
    try {
      return new Set(JSON.parse(localStorage.getItem("sm-favs") || "[]"));
    } catch { return new Set(); }
  });
  const [onlyFav, setOnlyFav] = useState(false);

  const rows = useMemo(() => {
    let r = onlyFav ? items.filter((q) => fav.has(q.asset_id)) : items;
    return [...r].sort((a, b) => {
      const av = sort.key === "symbol" ? a.symbol : Number(a[sort.key] ?? -Infinity);
      const bv = sort.key === "symbol" ? b.symbol : Number(b[sort.key] ?? -Infinity);
      const cmp = av < bv ? -1 : av > bv ? 1 : 0;
      return sort.asc ? cmp : -cmp;
    });
  }, [items, sort, fav, onlyFav]);

  const toggleFav = (id: string) => {
    const next = new Set(fav);
    next.has(id) ? next.delete(id) : next.add(id);
    setFav(next);
    localStorage.setItem("sm-favs", JSON.stringify([...next]));
  };
  const th = (k: Key, label: string) => (
    <th
      className="cursor-pointer py-2 text-right"
      onClick={() => setSort((s) => ({ key: k, asc: s.key === k ? !s.asc : false }))}
    >
      {label} {sort.key === k ? (sort.asc ? "↑" : "↓") : ""}
    </th>
  );

  return (
    <div>
      <label className="mb-2 flex items-center gap-2 text-xs text-neutral-500">
        <input type="checkbox" checked={onlyFav} onChange={(e) => setOnlyFav(e.target.checked)} />
        只看收藏
      </label>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-neutral-500">
            <th className="w-8" /><th className="py-2">Symbol</th><th>Name</th>
            {th("price", "Price")}{th("change_pct", "Chg%")}<th />
          </tr>
        </thead>
        <tbody>
          {rows.map((q) => (
            <tr key={q.asset_id} className="border-t">
              <td>
                <button onClick={() => toggleFav(q.asset_id)}
                  className={fav.has(q.asset_id) ? "text-yellow-500" : "text-neutral-300"}>★</button>
              </td>
              <td className="py-2 font-medium"><Link href={`/asset/${q.asset_id}`}>{q.symbol}</Link></td>
              <td className="text-neutral-500">{q.name}</td>
              <td className="text-right tabular-nums">{q.price ?? "—"}</td>
              <td className={`text-right tabular-nums ${Number(q.change_pct ?? 0) >= 0 ? "text-up" : "text-down"}`}>
                {q.change_pct != null ? `${q.change_pct}%` : "—"}
              </td>
              <td className="pl-2"><FreshnessBadge freshness={q.freshness} /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
