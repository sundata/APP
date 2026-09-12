import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

const String baseUrl = String.fromEnvironment('API_URL',
    defaultValue: 'http://localhost:8000');

class Api {
  String? token;
  Api({this.token});

  Map<String, String> get _h => {
        if (token != null) 'authorization': 'Bearer $token',
        'content-type': 'application/json',
      };

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await http.get(Uri.parse('$baseUrl$path'), headers: _h);
    if (r.statusCode >= 400) throw ApiError(r.statusCode, r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$baseUrl$path'),
        headers: _h, body: jsonEncode(body));
    if (r.statusCode >= 400) throw ApiError(r.statusCode, r.body);
    return r.statusCode == 204 ? {} : jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- auth ----
  Future<String> login(String email, String pw) async {
    final j = await _post('/api/v1/auth/login', {'email': email, 'password': pw});
    return j['access_token'] as String;
  }

  Future<String> register(String email, String pw) async {
    final j = await _post('/api/v1/auth/register', {'email': email, 'password': pw});
    return j['access_token'] as String;
  }

  // ---- quotes ----
  Future<List<Quote>> quotes({String category = 'stocks'}) async {
    final j = await _get('/api/v1/markets/$category');
    return (j['items'] as List)
        .map((e) => Quote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NewsItem>> news({String? category, String? importance}) async {
    var p = '/api/v1/news?';
    if (category != null) p += 'category=$category&';
    if (importance != null) p += 'importance=$importance&';
    final j = await _get(p);
    return (j['items'] as List)
        .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Quote>> search(String q) async {
    final j = await _get('/api/v1/search?q=${Uri.encodeComponent(q)}');
    return (j['items'] as List)
        .map((e) => Quote.fromJson({
              'asset_id': e['asset_id'], 'symbol': e['symbol'],
              'name': e['name'], 'asset_type': e['asset_type'],
              'currency': e['currency'], 'freshness': 'no_data',
            }))
        .toList();
  }

  // ---- calendar ----
  Future<List<Map<String, dynamic>>> calendar({String importance = 'high'}) async {
    final j = await _get('/api/v1/calendar/events?importance=$importance');
    return (j['items'] as List).cast<Map<String, dynamic>>();
  }

  // ---- watchlist (auth) ----
  Future<List<Map<String, dynamic>>> watchlists() async {
    final j = await _get('/api/v1/watchlists');
    return (j['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Quote>> watchlistItems(String wid) async {
    final j = await _get('/api/v1/watchlists/$wid/items');
    return (j['items'] as List)
        .map((e) => Quote.fromJson({
              'asset_id': e['asset_id'], 'symbol': e['symbol'],
              'name': e['symbol'], 'asset_type': 'stock',
              'currency': '', 'price': e['latest_price'],
              'change_pct': e['change_pct'], 'freshness': e['freshness'],
            }))
        .toList();
  }

  Future<void> addToWatchlist(String wid, String assetId) =>
      _post('/api/v1/watchlists/$wid/items', {'asset_id': assetId});

  Future<void> removeFromWatchlist(String wid, String assetId) async {
    await http.delete(
        Uri.parse('$baseUrl/api/v1/watchlists/$wid/items/$assetId'),
        headers: _h);
  }
}

class ApiError implements Exception {
  final int status; final String body;
  ApiError(this.status, this.body);
}
