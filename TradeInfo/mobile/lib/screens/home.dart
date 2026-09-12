import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/models.dart';
import '../state/prefs.dart';
import '../widgets/quote_tile.dart';
import 'asset.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  final api = Api();
  List<Quote> quotes = [];
  List<NewsItem> news = [];
  List<Map<String, dynamic>> events = [];
  bool offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = await api.quotes();
      final n = await api.news(importance: 'important');
      final ev = await api.calendar();
      setState(() {
        quotes = q.take(8).toList();
        news = n.take(5).toList();
        events = ev.take(5).toList();
      });
      QuoteCache.save(q.map((e) => e.toJson()).toList());
    } catch (_) {
      // AC-009: offline -> cached snapshot + offline state, not a blank page
      final cached = await QuoteCache.load();
      setState(() {
        offline = true;
        quotes = cached.map((e) => Quote.fromJson(e)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SimpleMarket')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          if (offline)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade100,
              child: const Text('离线模式 — 显示缓存数据',
                  style: TextStyle(fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('行情',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          ...quotes.map((q) => QuoteTile(
              quote: q,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AssetScreen(assetId: q.assetId))))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('重要新闻',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          ...news.map((n) => ListTile(
              dense: true, title: Text(n.title),
              subtitle: Text(n.source))),
          if (events.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('今日高影响事件',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            ...events.map((e) => ListTile(
                dense: true,
                title: Text(e['name'] as String? ?? ''),
                subtitle: Text(
                    '${(e['event_time_utc'] as String? ?? '').substring(11, 16)} UTC · ${e['country'] ?? ""}'))),
          ],
        ]),
      ),
    );
  }
}
