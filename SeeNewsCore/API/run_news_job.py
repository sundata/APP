"""Run one news crawl for Cloud Run Jobs."""

import asyncio

from server import run_crawler


if __name__ == "__main__":
    asyncio.run(run_crawler())
