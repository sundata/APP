import httpx
import pytest

from collector.breaker import CircuitOpenError
from collector.http import FetchError, HttpFetcher


def _client(statuses: list[int], calls: list[str]) -> httpx.Client:
    it = iter(statuses)

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(str(request.url))
        return httpx.Response(next(it), text="body")

    return httpx.Client(transport=httpx.MockTransport(handler))


def _fetcher(client: httpx.Client, **kw: object) -> HttpFetcher:
    kw.setdefault("sleep", lambda s: None)
    kw.setdefault("rate_per_sec", 1000.0)
    return HttpFetcher(client=client, **kw)  # type: ignore[arg-type]


def test_success_after_retryable_failures() -> None:
    calls: list[str] = []
    f = _fetcher(_client([500, 503, 200], calls))
    assert f.fetch_text("https://x/") == "body"
    assert len(calls) == 3


def test_gives_up_after_max_retries() -> None:
    calls: list[str] = []
    f = _fetcher(_client([500, 500, 500, 500], calls), max_retries=3)
    with pytest.raises(FetchError):
        f.fetch_text("https://x/")
    assert len(calls) == 4  # 1 + 3 retries


def test_4xx_not_retried() -> None:
    calls: list[str] = []
    f = _fetcher(_client([404], calls))
    with pytest.raises(FetchError):
        f.fetch_text("https://x/")
    assert len(calls) == 1


def test_429_retried() -> None:
    calls: list[str] = []
    f = _fetcher(_client([429, 200], calls))
    assert f.fetch_text("https://x/") == "body"
    assert len(calls) == 2


def test_breaker_opens_after_consecutive_failures() -> None:
    calls: list[str] = []
    f = _fetcher(
        _client([500] * 12, calls), max_retries=1, breaker_threshold=3
    )
    for _ in range(2):
        with pytest.raises(FetchError):
            f.fetch_text("https://x/")
    # 2 calls x (1+1 retries) = 4 failures >= threshold 3 -> open
    with pytest.raises(CircuitOpenError):
        f.fetch_text("https://x/")
    assert len(calls) == 4


def test_sends_user_agent() -> None:
    seen: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request.headers.get("user-agent", ""))
        return httpx.Response(200, text="ok")

    client = httpx.Client(transport=httpx.MockTransport(handler))
    f = _fetcher(client, user_agent="SimpleMarketCollector/0.1")
    f.fetch_text("https://x/")
    assert seen == ["SimpleMarketCollector/0.1"]
