"""Tick-level market data sink (DATABASE.md: ticks -> BigQuery, partitioned).

- JsonlTickSink: local/dev implementation, appends JSONL under the raw dir.
- BqTickSink: streams to BigQuery (lazy import — the driver is only needed in
  GCP deploys; add `google-cloud-bigquery` to requirements when wiring infra).
"""

import datetime
import json
from pathlib import Path
from typing import Any, Iterable, Optional, Protocol

_UTC = datetime.timezone.utc


class TickSink(Protocol):
    def write(self, ticks: Iterable[dict[str, Any]]) -> int: ...


class JsonlTickSink:
    """Dev sink: ticks/<source>/<YYYY-MM-DD>.jsonl under root."""

    def __init__(self, root: str = "./raw_data") -> None:
        self.root = Path(root)

    def write(self, ticks: Iterable[dict[str, Any]]) -> int:
        rows = list(ticks)
        if not rows:
            return 0
        day = datetime.datetime.now(_UTC).date()
        out_dir = self.root / "ticks" / str(rows[0].get("source_id", "unknown"))
        out_dir.mkdir(parents=True, exist_ok=True)
        path = out_dir / f"{day}.jsonl"
        with path.open("a", encoding="utf-8") as f:
            for t in rows:
                f.write(json.dumps(t, default=str) + "\n")
        return len(rows)


class BqTickSink:
    """Streams ticks into `project.dataset.ticks` (partitioned on ts, §DATABASE).

    Table DDL (apply via Terraform):
      asset_id STRING, symbol STRING, price NUMERIC, ts TIMESTAMP,
      source_id STRING  — PARTITION BY DATE(ts), CLUSTER BY asset_id
    """

    def __init__(
        self, table: str, client: Optional[Any] = None
    ) -> None:
        self.table = table
        if client is not None:
            self._client = client
        else:
            try:
                from google.cloud import bigquery  # type: ignore[import-not-found]
            except ImportError as e:
                raise RuntimeError(
                    "google-cloud-bigquery not installed — add it to "
                    "collectors/requirements.txt for GCP deploys"
                ) from e
            self._client = bigquery.Client()

    def write(self, ticks: Iterable[dict[str, Any]]) -> int:
        rows = [
            {
                "asset_id": t["asset_id"],
                "symbol": t["symbol"],
                "price": str(t["price"]),
                "ts": t["quote_ts"].isoformat()
                if isinstance(t["quote_ts"], datetime.datetime)
                else str(t["quote_ts"]),
                "source_id": t["source_id"],
            }
            for t in ticks
        ]
        if not rows:
            return 0
        errors = self._client.insert_rows_json(self.table, rows)
        if errors:
            raise RuntimeError(f"bigquery insert errors: {errors}")
        return len(rows)
