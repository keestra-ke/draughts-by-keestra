import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../brand.dart';
import '../state/game_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  LoginMode _mode = LoginMode.login;
  final _name = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    final store = context.read<GameStore>();
    store.login(_name.text.trim(), _pass.text, _mode);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GameStore>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/textures/leather.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.45)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    Brand.appName,
                    style: TextStyle(
                      color: Color(0xFFE8C87A),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kenyan Nairobi draughts',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _radio('Registered user', LoginMode.login),
                      const SizedBox(width: 18),
                      _radio('Guest', LoginMode.guest),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => setState(
                        () => _mode = _mode == LoginMode.register
                            ? LoginMode.login
                            : LoginMode.register),
                    child: Text(
                      _mode == LoginMode.register
                          ? 'Registration (selected)'
                          : 'Registration',
                      style: TextStyle(
                        color: _mode == LoginMode.register
                            ? const Color(0xFFE8C87A)
                            : Colors.white60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field('Login', _name),
                  const SizedBox(height: 12),
                  _field('Password', _pass, obscure: true),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4A2B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Login',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (store.status != null)
                    Text(store.status!,
                        style: const TextStyle(color: Colors.orangeAccent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radio(String label, LoginMode mode) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18, color: selected ? const Color(0xFFE8C87A) : Colors.white60),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.black.withOpacity(0.45),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}