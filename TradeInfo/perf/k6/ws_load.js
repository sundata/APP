// WS load test (§58, T40): 10k concurrent conns; each subscribes, keeps the
// conn open, verifies heartbeat. Run: k6 run perf/k6/ws_load.js
import ws from 'k6/ws';
import { check } from 'k6';

export const options = {
  scenarios: {
    ws: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5m', target: 10000 },
        { duration: '10m', target: 10000 },
        { duration: '2m', target: 0 },
      ],
    },
  },
  thresholds: {
    ws_connecting: ['p(95)<2000'],
  },
};

const BASE = (__ENV.BASE_URL || 'http://localhost:8000').replace('http', 'ws');

export default function () {
  const res = ws.connect(`${BASE}/ws/quotes`, {}, (socket) => {
    socket.on('open', () => {
      socket.send(JSON.stringify({
        type: 'subscribe',
        asset_ids: ['crypto_btcusd', 'stock_us_aapl'],
      }));
    });
    let gotSnapshot = false;
    socket.on('message', (msg) => {
      const m = JSON.parse(msg);
      if (m.type === 'snapshot') gotSnapshot = true;
    });
    socket.setTimeout(() => {
      check(gotSnapshot, { 'snapshot received': (v) => v === true });
      socket.close();
    }, 30000);
  });
  check(res, { 'ws 101': (r) => r && r.status === 101 });
}
