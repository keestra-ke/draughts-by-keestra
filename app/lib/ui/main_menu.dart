import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../brand.dart';
import '../state/game_store.dart';
import 'opened_games.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GameStore>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/textures/leather.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),
                const Text(Brand.appName,
                    style: TextStyle(
                        color: Color(0xFFE8C87A),
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  store.name == null ? 'Not signed in' : 'Signed in: ${store.name}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    children: [
                      _button(context, 'Play', () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const OpenedGamesScreen()));
                      }),
                      _button(context, 'Started games', () {}),
                      _button(context, 'User profile', () {}),
                      _button(context, 'Players', () {}),
                      _button(context, 'Settings', () {}),
                      _button(context, 'Connection log', () {}),
                      const SizedBox(height: 20),
                      _button(context, 'Quit', () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(BuildContext context, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B4A2B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ),
    );
  }
}