import Link from "next/link";
import { Quote } from "@/lib/api";
import { FreshnessBadge } from "./FreshnessBadge";

export function QuoteTable({ items }: { items: Quote[] }) {
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="text-left text-neutral-500">
          <th className="py-2">Symbol</th><th>Name</th>
          <th className="text-right">Price</th><th className="text-right">Chg%</th><th />
        </tr>
      </thead>
      <tbody>
        {items.map((q) => (
          <tr key={q.asset_id} className="border-t">
            <td className="py-2 font-medium">
              <Link href={`/asset/${q.asset_id}`}>{q.symbol}</Link>
            </td>
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
  );
}
