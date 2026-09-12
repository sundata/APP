// §9 Asset detail: price + freshness + line chart + related news.
import { api } from "@/lib/api";
import { FreshnessBadge } from "@/components/FreshnessBadge";
import { Sparkline } from "@/components/Sparkline";
import { LivePrice } from "@/components/LivePrice";
import { notFound } from "next/navigation";
import type { Metadata } from "next";

// §63 SEO: per-asset OG + JSON-LD structured data (SSR page already).
export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const a = await api.asset(params.id).catch(() => null);
  if (!a) return { title: "SimpleMarket" };
  return {
    title: `${a.symbol} — ${a.name} | SimpleMarket`,
    description: `${a.symbol} 最新价格 ${a.price ?? "—"} ${a.currency}`,
    openGraph: { title: `${a.symbol} | SimpleMarket`, type: "article" },
  };
}

export default async function AssetPage({ params, searchParams }: {
  params: { id: string }; searchParams: { range?: string };
}) {
  const range = searchParams.range ?? "1M";
  const [asset, chart] = await Promise.all([
    api.asset(params.id).catch(() => null),
    api.chart(params.id, range).catch(() => ({ points: [] })),
  ]);
  if (!asset) notFound();
  return (
    <div className="py-6">
      <div className="flex items-baseline gap-3">
        <h1 className="text-xl font-bold">{asset.symbol}</h1>
        <span className="text-neutral-500">{asset.name}</span>
        <FreshnessBadge freshness={asset.freshness} />
      </div>
      <LivePrice
        assetId={asset.asset_id}
        initialPrice={asset.price}
        initialPct={asset.change_pct}
        delayMinutes={asset.delay_minutes}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "FinancialProduct",
            name: asset.name,
            alternateName: asset.symbol,
            provider: { "@type": "Exchange", name: asset.exchange_id },
          }),
        }}
      />
      <div className="mt-4">
        <div className="mb-2 flex gap-1 text-xs">
          {["1D", "1W", "1M", "1Y"].map((r) => (
            <a key={r} href={`?range=${r}`}
              className={`rounded px-2 py-1 ${r === range ? "bg-neutral-100 dark:bg-neutral-800" : "text-neutral-500"}`}>
              {r}
            </a>
          ))}
        </div>
        <Sparkline points={chart.points} />
      </div>
      {asset.related_news?.length > 0 && (
        <section className="mt-6">
          <h2 className="mb-2 text-sm font-semibold text-neutral-500">相关新闻</h2>
          <ul className="space-y-1 text-sm">
            {asset.related_news.map((n) => (
              <li key={n.id}>
                <a href={n.source_url} target="_blank" className="hover:underline">{n.title}</a>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
