import 'package:flutter/material.dart';
import '../state/prefs.dart';

class SettingsScreen extends StatelessWidget {
  final Prefs prefs;
  const SettingsScreen({super.key, required this.prefs});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(children: [
        SwitchListTile(
          title: const Text('深色模式'),
          value: prefs.darkMode,
          onChanged: (v) { prefs.darkMode = v; prefs.save(); },
        ),
        SwitchListTile(
          title: const Text('红涨绿跌（亚洲配色）'),
          value: prefs.asianColors,
          onChanged: (v) { prefs.asianColors = v; prefs.save(); },
        ),
      ]),
    );
  }
}
