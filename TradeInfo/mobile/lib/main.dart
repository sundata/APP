import 'package:flutter/material.dart';
import 'state/prefs.dart';
import 'screens/home.dart';
import 'screens/markets.dart';
import 'screens/watchlist.dart';
import 'screens/news.dart';
import 'screens/settings.dart';
import 'screens/login.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final prefs = Prefs();
  @override
  void initState() {
    super.initState();
    prefs.load().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final up = prefs.asianColors ? Colors.red : Colors.green;
    final down = prefs.asianColors ? Colors.green : Colors.red;
    return MaterialApp(
      title: 'SimpleMarket',
      theme: ThemeData(
        brightness: prefs.darkMode ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: prefs.darkMode ? Brightness.dark : Brightness.light,
        ).copyWith(primary: up, secondary: down),
      ),
      home: MainTabs(prefs: prefs),
    );
  }
}

class MainTabs extends StatefulWidget {
  final Prefs prefs;
  const MainTabs({super.key, required this.prefs});
  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const MarketsScreen(),
      WatchlistScreen(prefs: widget.prefs),
      const NewsScreen(),
      SettingsScreen(prefs: widget.prefs),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home), label: _t(widget.prefs.locale, 'home')),
          NavigationDestination(
              icon: const Icon(Icons.show_chart), label: _t(widget.prefs.locale, 'markets')),
          NavigationDestination(
              icon: const Icon(Icons.star), label: _t(widget.prefs.locale, 'watchlist')),
          NavigationDestination(
              icon: const Icon(Icons.article), label: _t(widget.prefs.locale, 'news')),
          NavigationDestination(
              icon: const Icon(Icons.settings), label: _t(widget.prefs.locale, 'settings')),
        ],
      ),
    );
  }
}


String _t(String locale, String key) {
  const d = {
    'zh': {'home': '首页', 'markets': '行情', 'watchlist': '自选', 'news': '新闻', 'settings': '设置'},
    'en': {'home': 'Home', 'markets': 'Markets', 'watchlist': 'Watchlist', 'news': 'News', 'settings': 'Settings'},
    'ja': {'home': 'ホーム', 'markets': '相場', 'watchlist': 'ウォッチ', 'news': 'ニュース', 'settings': '設定'},
  };
  return d[locale]?[key] ?? key;
}
