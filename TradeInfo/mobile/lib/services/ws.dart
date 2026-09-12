import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

// /ws/quotes: subscribe -> snapshot -> deltas; reconnect+resync on drop.
class QuoteStream {
  final List<String> assetIds;
  final String url;
  final void Function(List<dynamic> quotes, String type) onQuotes;
  WebSocketChannel? _ch;
  Timer? _reconnect;
  int _retries = 0;
  bool _stopped = false;

  QuoteStream(this.assetIds,
      {required this.onQuotes,
      this.url = const String.fromEnvironment('WS_URL',
          defaultValue: 'ws://localhost:8000/ws/quotes')});

  void start() => _open();

  void _open() {
    _ch = WebSocketChannel.connect(Uri.parse(url));
    _ch!.sink.add(jsonEncode({'type': 'subscribe', 'asset_ids': assetIds}));
    _ch!.stream.listen((ev) {
      final m = jsonDecode(ev as String) as Map<String, dynamic>;
      if (m['type'] == 'snapshot' || m['type'] == 'delta') {
        onQuotes(m['quotes'] as List, m['type'] as String);
      }
    }, onDone: _scheduleReconnect, onError: (_) => _scheduleReconnect());
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    _reconnect?.cancel();
    _reconnect = Timer(
        Duration(milliseconds: 500 * (1 << _retries++).clamp(0, 6)), _open);
  }

  void dispose() {
    _stopped = true;
    _reconnect?.cancel();
    _ch?.sink.close();
  }
}
