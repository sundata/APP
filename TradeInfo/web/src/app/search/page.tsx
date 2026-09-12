"use client";
// AC-004: global search across symbols, names, aliases, identifiers.
import { useEffect, useRef, useState } from "react";
import { api } from "@/lib/api";
import Link from "next/link";

type Hit = { asset_id: string; symbol: string; name: string; asset_type: string };

export default function SearchPage() {
  const [q, setQ] = useState("");
  const [hits, setHits] = useState<Hit[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);
  useEffect(() => { inputRef.current?.focus(); }, []);
  useEffect(() => {
    if (!q.trim()) { setHits([]); return; }
    const t = setTimeout(() => api.search(q).then((r) => setHits(r.items)).catch(() => {}), 200);
    return () => clearTimeout(t);
  }, [q]);
  return (
    <div className="py-6">
      <input
        ref={inputRef}
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder="代码 / 名称 / 别名 / ISIN"
        className="w-full rounded border px-4 py-2 dark:bg-neutral-900"
      />
      <ul className="mt-4 divide-y">
        {hits.map((h) => (
          <li key={h.asset_id} className="py-2">
            <Link href={`/asset/${h.asset_id}`} className="flex gap-3">
              <span className="font-medium">{h.symbol}</span>
              <span className="text-neutral-500">{h.name}</span>
              <span className="ml-auto text-xs text-neutral-400">{h.asset_type}</span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
