import 'package:flutter/material.dart';
import '../services/api.dart';
import '../models/models.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsState();
}

class _NewsState extends State<NewsScreen> {
  final api = Api();
  List<NewsItem> items = [];

  @override
  void initState() {
    super.initState();
    api.news().then((v) => setState(() => items = v)).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新闻')),
      body: ListView(children: items.map((n) => ListTile(
        title: Text(n.title),
        subtitle: Text('${n.source} · ${n.publishedAt?.substring(0, 16) ?? ""}'),
      )).toList()),
    );
  }
}
