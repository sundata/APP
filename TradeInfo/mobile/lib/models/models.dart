// API models (mirror api/openapi.yaml, decimal-as-string).
class Quote {
  final String assetId, symbol, name, assetType, currency, freshness;
  final String? price, changePct, quoteTs;
  final int delayMinutes;
  Quote.fromJson(Map<String, dynamic> j)
      : assetId = j['asset_id'], symbol = j['symbol'], name = j['name'],
        assetType = j['asset_type'], currency = j['currency'],
        price = j['price'], changePct = j['change_pct'],
        quoteTs = j['quote_ts'], delayMinutes = j['delay_minutes'] ?? 0,
        freshness = j['freshness'] ?? 'no_data';
  Map<String, dynamic> toJson() => {
        'asset_id': assetId, 'symbol': symbol, 'name': name,
        'asset_type': assetType, 'currency': currency, 'price': price,
        'change_pct': changePct, 'quote_ts': quoteTs,
        'delay_minutes': delayMinutes, 'freshness': freshness,
      };
}

class NewsItem {
  final String id, title, source, sourceUrl;
  final String? summary, publishedAt;
  final int importanceScore, dedupCount;
  NewsItem.fromJson(Map<String, dynamic> j)
      : id = j['id'], title = j['title'], source = j['source'],
        sourceUrl = j['source_url'], summary = j['summary'],
        publishedAt = j['published_at'],
        importanceScore = j['importance_score'] ?? 0,
        dedupCount = j['dedup_count'] ?? 1;
}
