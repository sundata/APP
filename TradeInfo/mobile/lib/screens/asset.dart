import 'package:flutter/material.dart';
import '../services/ws.dart';

// Asset detail with WS live updates (AC-002).
class AssetScreen extends StatefulWidget {
  final String assetId;
  const AssetScreen({super.key, required this.assetId});
  @override
  State<AssetScreen> createState() => _AssetState();
}

class _AssetState extends State<AssetScreen> {
  String? price, changePct;
  late QuoteStream stream;

  @override
  void initState() {
    super.initState();
    stream = QuoteStream([widget.assetId], onQuotes: (quotes, _) {
      final q = quotes.firstWhere(
          (e) => e['asset_id'] == widget.assetId, orElse: () => null);
      if (q != null && mounted) {
        setState(() {
          price = q['price'];
          changePct = q['change_pct'];
        });
      }
    })..start();
  }

  @override
  void dispose() { stream.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pct = double.tryParse(changePct ?? '') ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.assetId)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(price ?? '—', style: const TextStyle(fontSize: 40)),
          Text('${pct >= 0 ? "+" : ""}$changePct%',
              style: TextStyle(
                  color: pct >= 0
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary)),
        ]),
      ),
    );
  }
}
