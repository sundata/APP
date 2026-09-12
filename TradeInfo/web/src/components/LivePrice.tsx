"use client";
// AC-002: asset price auto-updates over /ws/quotes.
import { useEffect, useState } from "react";
import { connectQuotes } from "@/lib/ws";

export function LivePrice({
  assetId, initialPrice, initialPct, delayMinutes,
}: {
  assetId: string; initialPrice: string | null;
  initialPct: string | null; delayMinutes: number;
}) {
  const [price, setPrice] = useState(initialPrice);
  const [pct, setPct] = useState(initialPct);
  useEffect(() => {
    const conn = connectQuotes([assetId], (quotes) => {
      const q = quotes.find((x) => x.asset_id === assetId);
      if (q) {
        if (q.price != null) setPrice(q.price);
        if (q.change_pct != null) setPct(q.change_pct);
      }
    });
    return () => conn.close();
  }, [assetId]);
  const up = Number(pct ?? 0) >= 0;
  return (
    <div className="mt-2 flex items-baseline gap-3">
      <span className="text-3xl tabular-nums">{price ?? "—"}</span>
      <span className={`tabular-nums ${up ? "text-up" : "text-down"}`}>
        {pct != null ? `${up ? "+" : ""}${pct}%` : ""}
      </span>
      {delayMinutes > 0 && (
        <span className="text-xs text-neutral-400">延迟 {delayMinutes}m</span>
      )}
    </div>
  );
}
