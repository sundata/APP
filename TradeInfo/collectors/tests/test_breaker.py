import pytest

from collector.breaker import CircuitBreaker, CircuitOpenError


class FakeClock:
    def __init__(self) -> None:
        self.t = 0.0

    def __call__(self) -> float:
        return self.t


def test_opens_after_threshold_and_blocks() -> None:
    clock = FakeClock()
    b = CircuitBreaker(threshold=3, reset_after=60.0, clock=clock)
    for _ in range(2):
        b.record_failure()
        b.check()  # still closed
    b.record_failure()
    assert b.is_open
    with pytest.raises(CircuitOpenError):
        b.check()


def test_half_open_after_reset_then_close_on_success() -> None:
    clock = FakeClock()
    b = CircuitBreaker(threshold=2, reset_after=60.0, clock=clock)
    b.record_failure()
    b.record_failure()
    assert b.is_open
    clock.t = 61.0
    b.check()  # half-open allows a probe
    b.record_success()
    assert not b.is_open


def test_success_resets_failure_count() -> None:
    b = CircuitBreaker(threshold=2, reset_after=60.0, clock=FakeClock())
    b.record_failure()
    b.record_success()
    b.record_failure()
    assert not b.is_open
