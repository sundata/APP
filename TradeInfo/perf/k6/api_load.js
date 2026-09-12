// API load test (REQUIREMENTS §58, T40): 1k concurrent, P95<500ms, error<1%.
// Run: k6 run perf/k6/api_load.js -e BASE_URL=https://api.example.com
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    api: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 1000 },
        { duration: '5m', target: 1000 },
        { duration: '2m', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
};

const BASE = __ENV.BASE_URL || 'http://localhost:8000';

export default function () {
  const res = http.batch([
    ['GET', `${BASE}/api/v1/markets/quotes?limit=50`],
    ['GET', `${BASE}/api/v1/news?limit=30`],
    ['GET', `${BASE}/api/v1/search?q=apple`],
    ['GET', `${BASE}/api/v1/calendar/events`],
    ['GET', `${BASE}/api/v1/assets/stock_us_aapl`],
  ]);
  for (const r of res) {
    check(r, {
      'status 2xx': (x) => x.status >= 200 && x.status < 400,
      'has body': (x) => x.body && x.body.length > 0,
    });
  }
  sleep(1);
}
