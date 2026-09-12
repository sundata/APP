from collector.ratelimit import RateLimiter


class FakeClock:
    def __init__(self) -> None:
        self.t = 0.0

    def __call__(self) -> float:
        return self.t


def test_burst_then_throttle() -> None:
    clock = FakeClock()
    sleeps: list[float] = []
    rl = RateLimiter(
        2.0,
        clock=clock,
        sleep=lambda s: (sleeps.append(s), setattr(clock, "t", clock.t + s)),
    )
    rl.acquire()
    rl.acquire()  # burst of 2 OK
    rl.acquire()  # must wait 0.5s
    assert sleeps == [0.5]


def test_zero_rate_rejected() -> None:
    try:
        RateLimiter(0)
    except ValueError:
        return
    raise AssertionError("expected ValueError")
