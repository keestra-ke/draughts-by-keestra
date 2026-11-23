import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'brand.dart';
import 'state/game_store.dart';
import 'ui/login_screen.dart';
import 'ui/main_menu.dart';
import 'ui/board_screen.dart';

void main() {
  runApp(ChangeNotifierProvider(
    create: (_) => GameStore(),
    child: const KeestraApp(),
  ));
}

class KeestraApp extends StatelessWidget {
  const KeestraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E140C),
        primaryColor: const Color(0xFF6B4A2B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8C87A),
          secondary: Color(0xFF6B4A2B),
        ),
      ),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameStore>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GameStore>();
    if (store.game != null) return const BoardScreen();
    if (store.loggedIn) return const MainMenu();
    return const LoginScreen();
  }
}