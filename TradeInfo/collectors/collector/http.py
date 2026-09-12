"""HTTP fetcher with retry + exponential backoff + rate limit + circuit breaker
(REQUIREMENTS §19.1). Sync httpx: collectors run as scheduled jobs, not servers.

No CAPTCHA bypass / anti-bot evasion — ever (§19.1, §17).
"""

import time
from typing import Callable, Optional

import httpx

from collector.breaker import CircuitBreaker
from collector.ratelimit import RateLimiter


class FetchError(Exception):
    pass


_RETRYABLE_STATUS = {429, 500, 502, 503, 504}


class HttpFetcher:
    def __init__(
        self,
        *,
        timeout: float = 10.0,
        max_retries: int = 3,
        backoff_base: float = 0.5,
        rate_per_sec: float = 5.0,
        breaker_threshold: int = 5,
        breaker_reset: float = 60.0,
        user_agent: str = "SimpleMarketCollector/0.1",
        client: Optional[httpx.Client] = None,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self.timeout = timeout
        self.max_retries = max_retries
        self.backoff_base = backoff_base
        self._sleep = sleep
        self.user_agent = user_agent
        self._breaker = CircuitBreaker(threshold=breaker_threshold, reset_after=breaker_reset)
        self._rate = RateLimiter(rate_per_sec, sleep=sleep)
        self._client = client or httpx.Client(timeout=timeout)

    def fetch_text(self, url: str) -> str:
        """GET url with retries. Raises FetchError / CircuitOpenError on failure."""
        self._breaker.check()
        last_error: Optional[Exception] = None
        for attempt in range(self.max_retries + 1):
            self._rate.acquire()
            try:
                resp = self._client.get(url, headers={"User-Agent": self.user_agent})
                if resp.status_code in _RETRYABLE_STATUS:
                    raise FetchError(f"retryable http {resp.status_code}")
                if resp.status_code >= 400:
                    # 4xx (except 429) is a permanent failure — no point retrying
                    raise FetchError(f"http {resp.status_code} (non-retryable)")
                self._breaker.record_success()
                return resp.text
            except FetchError as e:
                last_error = e
                if "non-retryable" in str(e):
                    self._breaker.record_failure()
                    raise
                self._breaker.record_failure()
            except httpx.HTTPError as e:
                last_error = e
                self._breaker.record_failure()
            if attempt < self.max_retries:
                self._sleep(self.backoff_base * (2**attempt))
        raise FetchError(f"giving up after {self.max_retries + 1} attempts") from last_error
