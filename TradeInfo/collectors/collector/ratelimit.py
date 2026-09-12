"""Token-bucket rate limiter (REQUIREMENTS §19.1). Clock is injectable so tests
are deterministic."""

import time
from typing import Callable


class RateLimiter:
    def __init__(
        self,
        rate_per_sec: float,
        clock: Callable[[], float] = time.monotonic,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        if rate_per_sec <= 0:
            raise ValueError("rate_per_sec must be > 0")
        self.rate = rate_per_sec
        self._clock = clock
        self._sleep = sleep
        self._tokens = rate_per_sec
        self._last = self._clock()

    def acquire(self) -> None:
        now = self._clock()
        self._tokens = min(self.rate, self._tokens + (now - self._last) * self.rate)
        self._last = now
        if self._tokens < 1.0:
            wait = (1.0 - self._tokens) / self.rate
            self._sleep(wait)
            self._tokens = 0.0
            self._last = self._clock()
        else:
            self._tokens -= 1.0
