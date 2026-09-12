import 'package:flutter_test/flutter_test.dart';
import 'package:simplemarket/models/models.dart';

void main() {
  test('Quote.fromJson parses', () {
    final q = Quote.fromJson({
      'asset_id': 'a', 'symbol': 'AAPL', 'name': 'Apple',
      'asset_type': 'stock', 'currency': 'USD', 'price': '250',
      'change_pct': '1.2', 'quote_ts': '2026-01-01T00:00:00Z',
      'delay_minutes': 15, 'freshness': 'delayed',
    });
    expect(q.symbol, 'AAPL');
    expect(q.freshness, 'delayed');
  });
}
