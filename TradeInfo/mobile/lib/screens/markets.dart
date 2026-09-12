import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/models.dart';
import '../widgets/quote_tile.dart';
import 'asset.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});
  @override
  State<MarketsScreen> createState() => _MarketsState();
}

class _MarketsState extends State<MarketsScreen> {
  static const cats = ['stocks', 'indices', 'forex', 'crypto', 'commodities', 'bonds'];
  String cat = 'stocks';
  List<Quote> items = [];
  final api = Api();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { setState(() async => items = await api.quotes(category: cat)); }
    catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('行情')),
      body: Column(children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: cats.map((c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(c),
                selected: c == cat,
                onSelected: (_) { cat = c; _load(); setState(() {}); },
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: ListView(children: items.map((q) => QuoteTile(
            quote: q,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AssetScreen(assetId: q.assetId))),
          )).toList()),
        ),
      ]),
    );
  }
}
