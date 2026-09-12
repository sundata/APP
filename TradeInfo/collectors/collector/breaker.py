"""Circuit breaker (REQUIREMENTS §19.1). Opens after N consecutive failures;
half-opens after `reset_after` seconds to probe recovery."""

import time
from typing import Callable, Optional


class CircuitOpenError(Exception):
    pass


class CircuitBreaker:
    def __init__(
        self,
        threshold: int = 5,
        reset_after: float = 60.0,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.threshold = threshold
        self.reset_after = reset_after
        self._clock = clock
        self._failures = 0
        self._opened_at: Optional[float] = None

    @property
    def is_open(self) -> bool:
        return self._opened_at is not None and not self._half_open_due()

    def _half_open_due(self) -> bool:
        return (
            self._opened_at is not None
            and self._clock() - self._opened_at >= self.reset_after
        )

    def check(self) -> None:
        if self.is_open:
            raise CircuitOpenError("circuit breaker open")

    def record_success(self) -> None:
        self._failures = 0
        self._opened_at = None

    def record_failure(self) -> None:
        self._failures += 1
        if self._failures >= self.threshold and self._opened_at is None:
            self._opened_at = self._clock()
