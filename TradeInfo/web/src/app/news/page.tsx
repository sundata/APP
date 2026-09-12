// §11 News: importance filter + category chips.
import { api } from "@/lib/api";
import Link from "next/link";

export default async function NewsPage({ searchParams }: { searchParams: { importance?: string; category?: string } }) {
  const p = new URLSearchParams();
  if (searchParams.importance) p.set("importance", searchParams.importance);
  if (searchParams.category) p.set("category", searchParams.category);
  const data = await api.news(`?${p}`).catch(() => ({ items: [], next_cursor: null }));
  return (
    <div className="py-6">
      <div className="mb-4 flex gap-2 text-sm">
        <Link href="/news">全部</Link>
        <Link href="/news?importance=important">重要</Link>
        {["macro", "earnings", "crypto", "company"].map((c) => (
          <Link key={c} href={`/news?category=${c}`} className="capitalize">{c}</Link>
        ))}
      </div>
      <ul className="space-y-3">
        {data.items.map((n) => (
          <li key={n.id}>
            <a href={n.source_url} target="_blank" className="hover:underline">{n.title}</a>
            <div className="text-xs text-neutral-400">
              {n.source} · {n.published_at?.slice(0, 16) ?? ""}
              {n.dedup_count > 1 && <span className="ml-1">· {n.dedup_count} 家转载</span>}
            </div>
            {n.summary && <p className="mt-1 text-sm text-neutral-500">{n.summary}</p>}
          </li>
        ))}
      </ul>
    </div>
  );
}
