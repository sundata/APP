import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/models.dart';
import '../state/prefs.dart';
import '../widgets/quote_tile.dart';
import 'asset.dart';
import 'login.dart';

class WatchlistScreen extends StatefulWidget {
  final Prefs prefs;
  const WatchlistScreen({super.key, required this.prefs});
  @override
  State<WatchlistScreen> createState() => _WatchlistState();
}

class _WatchlistState extends State<WatchlistScreen> {
  List<Quote> items = [];
  String? wid;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = Api(token: widget.prefs.token);
    try {
      final lists = await api.watchlists();
      if (lists.isEmpty) return;
      wid = lists.first['id'] as String;
      final its = await api.watchlistItems(wid!);
      setState(() { items = its; error = null; });
    } catch (e) {
      setState(() => error = 'load failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.prefs.token == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('自选')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LoginScreen(prefs: widget.prefs))),
            child: const Text('登录后使用自选'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('自选')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: items.isEmpty && error == null
            ? const Center(child: Text('还没有自选 — 在资产页点 ★ 加入'))
            : ListView(children: items.map((q) => QuoteTile(
                quote: q,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AssetScreen(assetId: q.assetId))),
              )).toList()),
      ),
    );
  }
}
