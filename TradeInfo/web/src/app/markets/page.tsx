// §8 Markets: category tabs + quote table.
import { api } from "@/lib/api";
import { SortableQuoteTable } from "@/components/SortableQuoteTable";
import Link from "next/link";

const CATS = ["stocks", "indices", "forex", "crypto", "commodities", "bonds", "etfs"];

export default async function Markets({ searchParams }: { searchParams: { cat?: string } }) {
  const cat = searchParams.cat ?? "stocks";
  const data = await api.marketCategory(cat).catch(() => ({ items: [] }));
  return (
    <div className="py-6">
      <div className="mb-4 flex gap-1 overflow-x-auto">
        {CATS.map((c) => (
          <Link key={c} href={`/markets?cat=${c}`}
            className={`rounded px-3 py-1 text-sm capitalize ${c === cat ? "bg-neutral-100 font-medium dark:bg-neutral-800" : "text-neutral-500"}`}>
            {c}
          </Link>
        ))}
      </div>
      <SortableQuoteTable items={data.items} />
    </div>
  );
}
