import 'package:flutter/material.dart';
import '../models/models.dart';

class QuoteTile extends StatelessWidget {
  final Quote quote;
  final VoidCallback? onTap;
  const QuoteTile({super.key, required this.quote, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = double.tryParse(quote.changePct ?? '') ?? 0;
    final color = pct >= 0
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return ListTile(
      title: Text(quote.symbol),
      subtitle: Text(quote.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(quote.price ?? '—',
              style: const TextStyle(fontFeatures: [])),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${quote.changePct ?? "—"}%',
                style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(width: 4),
            _FreshnessChip(freshness: quote.freshness),
          ]),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _FreshnessChip extends StatelessWidget {
  final String freshness;
  const _FreshnessChip({required this.freshness});
  @override
  Widget build(BuildContext context) {
    final c = {
      'live': Colors.green, 'delayed': Colors.amber,
      'stale': Colors.orange, 'closed': Colors.grey, 'no_data': Colors.grey,
    }[freshness]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
      child: Text(freshness, style: TextStyle(fontSize: 9, color: c)),
    );
  }
}
