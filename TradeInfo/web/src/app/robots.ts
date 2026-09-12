// §63: user pages noindex; asset/news pages indexable.
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      { userAgent: "*", allow: "/", disallow: ["/watchlist", "/settings", "/login", "/portfolio", "/alerts"] },
    ],
  };
}
