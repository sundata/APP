import 'package:flutter/material.dart';
import '../services/api.dart';
import '../state/prefs.dart';

class LoginScreen extends StatefulWidget {
  final Prefs prefs;
  const LoginScreen({super.key, required this.prefs});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _register = false;
  String? _error;

  Future<void> _submit() async {
    setState(() => _error = null);
    final api = Api();
    try {
      final tok = _register
          ? await api.register(_email.text.trim(), _pw.text)
          : await api.login(_email.text.trim(), _pw.text);
      widget.prefs.token = tok;
      await widget.prefs.save();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? '注册' : '登录')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'email')),
          TextField(controller: _pw, obscureText: true,
              decoration: const InputDecoration(labelText: 'password')),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _submit,
              child: Text(_register ? '注册' : '登录')),
          TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register ? '已有账号？登录' : '没有账号？注册')),
        ]),
      ),
    );
  }
}
