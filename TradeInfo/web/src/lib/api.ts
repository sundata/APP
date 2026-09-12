// Typed API client — mirrors api/openapi.yaml. Base URL from env.

const BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

async function req<T>(path: string, init?: RequestInit, token?: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    ...init,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(init?.headers || {}),
    },
    cache: "no-store",
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new ApiError(res.status, body?.error?.code ?? "error", body?.error?.message ?? res.statusText);
  }
  return res.status === 204 ? (undefined as T) : res.json();
}

// ---- types (subset of openapi schemas) ----
export interface Quote {
  asset_id: string; symbol: string; name: string; asset_type: string;
  exchange_id: string | null; currency: string;
  price: string | null; change_pct: string | null; quote_ts: string | null;
  delay_minutes: number; freshness: "live"|"delayed"|"stale"|"closed"|"no_data";
}
export interface AssetDetail extends Quote {
  name_i18n: Record<string, string>; exchange_timezone: string | null;
  is_watchlisted: boolean; related_news: NewsItem[];
}
export interface NewsItem {
  id: string; title: string; summary: string | null; source: string;
  source_url: string; published_at: string | null; importance_score: number;
  dedup_count: number; related_assets: string[];
}
export interface CalendarEvent {
  id: string; name: string; country: string; currency: string;
  importance: string; event_time_utc: string;
  actual: string | null; forecast: string | null; previous: string | null;
}
export interface ChartPoint { ts: string; price: string; }
export interface Watchlist { id: string; name: string; item_count: number; }
export interface TokenPair {
  access_token: string; refresh_token: string; token_type: string;
  expires_in: number; user: User;
}
export interface User {
  id: string; email: string; display_name: string | null;
  locale: string; provider: string; settings: Record<string, unknown>;
}

// ---- read endpoints ----
export const api = {
  quotes: (params = "") => req<{ items: Quote[]; next_cursor: string | null }>(`/api/v1/markets/quotes${params}`),
  marketCategory: (cat: string) => req<{ items: Quote[] }>(`/api/v1/markets/${cat}`),
  asset: (id: string) => req<AssetDetail>(`/api/v1/assets/${id}`),
  chart: (id: string, range = "1M") => req<{ points: ChartPoint[] }>(`/api/v1/assets/${id}/chart?range=${range}`),
  news: (params = "") => req<{ items: NewsItem[]; next_cursor: string | null }>(`/api/v1/news${params}`),
  calendar: (params = "") => req<{ items: CalendarEvent[]; next_cursor: string | null }>(`/api/v1/calendar/events${params}`),
  search: (q: string) => req<{ items: { asset_id: string; symbol: string; name: string; asset_type: string }[] }>(`/api/v1/search?q=${encodeURIComponent(q)}`),
  // ---- auth ----
  login: (email: string, password: string) => req<TokenPair>("/api/v1/auth/login", { method: "POST", body: JSON.stringify({ email, password }) }),
  register: (email: string, password: string) => req<TokenPair>("/api/v1/auth/register", { method: "POST", body: JSON.stringify({ email, password }) }),
  // ---- authed ----
  watchlists: (t: string) => req<{ items: Watchlist[] }>("/api/v1/watchlists", {}, t),
  watchlistItems: (t: string, wid: string) => req<{ items: Quote[] & { asset_id: string }[] }>(`/api/v1/watchlists/${wid}/items`, {}, t),
  addWatchlistItem: (t: string, wid: string, asset_id: string) => req<unknown>(`/api/v1/watchlists/${wid}/items`, { method: "POST", body: JSON.stringify({ asset_id }) }, t),
  delWatchlistItem: (t: string, wid: string, asset_id: string) => req<void>(`/api/v1/watchlists/${wid}/items/${asset_id}`, { method: "DELETE" }, t),
};
