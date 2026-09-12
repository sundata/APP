// §63: static + top asset URLs for SEO.
import type { MetadataRoute } from "next";

const TOP_ASSETS = [
  "crypto_btcusd", "crypto_ethusd", "stock_us_aapl", "stock_us_msft",
  "stock_jp_7203", "index_us_spx", "forex_usdjpy",
];

export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
  return [
    { url: base, changeFrequency: "always", priority: 1 },
    { url: `${base}/markets`, changeFrequency: "always", priority: 0.9 },
    { url: `${base}/news`, changeFrequency: "hourly", priority: 0.8 },
    { url: `${base}/calendar`, changeFrequency: "daily", priority: 0.7 },
    ...TOP_ASSETS.map((id) => ({
      url: `${base}/asset/${id}`, changeFrequency: "always" as const, priority: 0.8,
    })),
  ];
}
