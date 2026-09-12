import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Prefs: theme, asianColors (红涨绿跌), locale — synced with web settings.
class Prefs extends ChangeNotifier {
  bool darkMode = false;
  bool asianColors = true;
  String locale = 'zh';
  String? token;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    darkMode = p.getBool('darkMode') ?? false;
    asianColors = p.getBool('asianColors') ?? true;
    locale = p.getString('locale') ?? 'zh';
    token = p.getString('token');
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('darkMode', darkMode);
    await p.setBool('asianColors', asianColors);
    await p.setString('locale', locale);
    if (token != null) await p.setString('token', token!);
  }
}

// Offline snapshot cache (AC-009): last-seen quotes per key.
class QuoteCache {
  static Future<void> save(List<dynamic> quotes) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('quote_cache', jsonEncode(quotes));
  }

  static Future<List<dynamic>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('quote_cache');
    return raw == null ? [] : jsonDecode(raw) as List<dynamic>;
  }
}
