// §11 Calendar: today default + High impact toggle (AC-007).
import { api } from "@/lib/api";
import Link from "next/link";

export default async function CalendarPage({ searchParams }: { searchParams: { importance?: string } }) {
  const importance = searchParams.importance ?? "high";
  const data = await api.calendar(`?importance=${importance}`).catch(() => ({ items: [], next_cursor: null }));
  return (
    <div className="py-6">
      <div className="mb-4 flex gap-2 text-sm">
        <Link href="/calendar?importance=high">高影响</Link>
        <Link href="/calendar?importance=all">全部</Link>
      </div>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-neutral-500">
            <th className="py-2">时间 (UTC)</th><th>事件</th><th>国家</th>
            <th className="text-right">实际</th><th className="text-right">预期</th>
          </tr>
        </thead>
        <tbody>
          {data.items.map((e) => (
            <tr key={e.id} className="border-t">
              <td className="py-2 tabular-nums">{e.event_time_utc.slice(5, 16)}</td>
              <td>{e.name}</td>
              <td className="text-neutral-500">{e.country}</td>
              <td className="text-right tabular-nums">{e.actual ?? "—"}</td>
              <td className="text-right tabular-nums text-neutral-500">{e.forecast ?? "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
