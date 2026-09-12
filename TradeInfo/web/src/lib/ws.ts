// /ws/quotes client: subscribe -> snapshot, delta frames, reconnect+resync.
export type QuoteFrame = { asset_id: string; price: string | null; change_pct: string | null; quote_ts: string | null; };

export function connectQuotes(
  assetIds: string[],
  onQuotes: (quotes: QuoteFrame[], type: "snapshot" | "delta") => void,
  opts: { url?: string; onClose?: () => void } = {},
) {
  const url = opts.url || (process.env.NEXT_PUBLIC_WS_URL || "ws://localhost:8000") + "/ws/quotes";
  let ws: WebSocket | null = null;
  let stopped = false;
  let retries = 0;

  function open() {
    ws = new WebSocket(url);
    ws.onopen = () => {
      retries = 0;
      ws!.send(JSON.stringify({ type: "subscribe", asset_ids: assetIds }));
    };
    ws.onmessage = (ev) => {
      const m = JSON.parse(ev.data);
      if (m.type === "snapshot" || m.type === "delta") onQuotes(m.quotes, m.type);
    };
    ws.onclose = () => {
      opts.onClose?.();
      if (!stopped) {
        const delay = Math.min(30000, 500 * 2 ** retries++); // backoff reconnect
        setTimeout(open, delay);
      }
    };
  }
  open();
  return {
    close() { stopped = true; ws?.close(); },
    resync() { ws?.send(JSON.stringify({ type: "resync" })); },
  };
}
