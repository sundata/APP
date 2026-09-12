"""Raw payload archive (REQUIREMENTS §20).

Prod layout targets gs://market-data-raw/<type>/<source>/YYYY/MM/DD/HH/*.jsonl;
locally the same layout is written under RAW_DATA_DIR (or a tmp dir). Each
record carries the mandatory envelope: source, source_url, fetched_at,
content_hash, payload.
"""

import datetime
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Iterable, Optional

_UTC = datetime.timezone.utc


class RawStore:
    def __init__(self, root: Optional[str] = None) -> None:
        resolved = root if root is not None else os.environ.get("RAW_DATA_DIR", "./raw_data")
        self.root = Path(resolved)

    def write(
        self,
        data_type: str,
        source_id: str,
        payloads: Iterable[dict[str, Any]],
        source_url: Optional[str] = None,
        now: Optional[datetime.datetime] = None,
    ) -> Path:
        now = now or datetime.datetime.now(_UTC)
        out_dir = (
            self.root
            / data_type
            / source_id
            / f"{now:%Y/%m/%d/%H}"
        )
        out_dir.mkdir(parents=True, exist_ok=True)
        path = out_dir / f"{now:%Y%m%dT%H%M%S}.jsonl"
        with path.open("w", encoding="utf-8") as f:
            for payload in payloads:
                body = json.dumps(payload, sort_keys=True, default=str)
                record = {
                    "source": source_id,
                    "source_url": source_url,
                    "fetched_at": now.isoformat(),
                    "content_hash": hashlib.sha256(body.encode()).hexdigest(),
                    "payload": payload,
                }
                f.write(json.dumps(record, default=str) + "\n")
        return path
