import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../protocol/codec.dart';

import '../state/game_store.dart';

class OpenedGamesScreen extends StatefulWidget {
  const OpenedGamesScreen({super.key});

  @override
  State<OpenedGamesScreen> createState() => _OpenedGamesScreenState();
}

class _OpenedGamesScreenState extends State<OpenedGamesScreen> {
  int _variant = Variant.towers;
  bool _ratingOnly = false;
  bool _hideUnplayed = false;

  static const _kinds = [
    ('Kenyan Nairobi', Variant.towers),
    ('Russian', Variant.russian),
    ('Give-away', Variant.giveaway),
    ('Checkers/American', Variant.checkers),
    ('Laska', Variant.laska),
    ('International/Polish', Variant.international),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameStore>().subscribeLobby();
    });
  }

  void _create({int minutes = 3, int increment = 0}) {
    final store = context.read<GameStore>();
    store.createGame(variant: _variant, minutes: minutes, increment: increment);
  }

  Future<void> _customGame() async {
    var minutes = 3;
    var increment = 0;
    var color = ColorChoice.any;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF2A1B10),
          title: const Text('Create Custom Game',
              style: TextStyle(color: Color(0xFFE8C87A))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Text('Initial time (minutes): ',
                    style: TextStyle(color: Colors.white)),
                DropdownButton<int>(
                  value: minutes,
                  dropdownColor: const Color(0xFF2A1B10),
                  items: [1, 3, 5, 10]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                      .toList(),
                  onChanged: (v) => setLocal(() => minutes = v!),
                ),
              ]),
              Row(children: [
                const Text('Add per move (seconds): ',
                    style: TextStyle(color: Colors.white)),
                DropdownButton<int>(
                  value: increment,
                  dropdownColor: const Color(0xFF2A1B10),
                  items: [0, 2, 5]
                      .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                      .toList(),
                  onChanged: (v) => setLocal(() => increment = v!),
                ),
              ]),
              Row(children: [
                const Text('Your color: ', style: TextStyle(color: Colors.white)),
                DropdownButton<int>(
                  value: color,
                  dropdownColor: const Color(0xFF2A1B10),
                  items: const [
                    DropdownMenuItem(value: ColorChoice.any, child: Text('Any')),
                    DropdownMenuItem(value: ColorChoice.white, child: Text('White')),
                    DropdownMenuItem(value: ColorChoice.black, child: Text('Black')),
                  ],
                  onChanged: (v) => setLocal(() => color = v!),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
          ],
        ),
      ),
    );
    if (result == true) _create(minutes: minutes, increment: increment);
  }

  Future<void> _filter() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF2A1B10),
          title: const Text('Games Filter',
              style: TextStyle(color: Color(0xFFE8C87A))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: _ratingOnly,
                onChanged: (v) => setLocal(() => _ratingOnly = v!),
                title: const Text('Only rating games',
                    style: TextStyle(color: Colors.white)),
              ),
              CheckboxListTile(
                value: _hideUnplayed,
                onChanged: (v) => setLocal(() => _hideUnplayed = v!),
                title: const Text('Hide non-played kinds of checkers',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GameStore>();
    final adverts = store.adverts
        .where((a) => a.variant == _variant)
        .where((a) => !_ratingOnly || a.rating > 0)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1E140C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1B10),
        title: const Text('Opened Games',
            style: TextStyle(color: Color(0xFFE8C87A))),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Text('Kind of checkers:',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int>(
                    value: _variant,
                    dropdownColor: const Color(0xFF2A1B10),
                    items: _kinds
                        .map((k) => DropdownMenuItem(
                            value: k.$2, child: Text(k.$1)))
                        .toList(),
                    onChanged: (v) => setState(() => _variant = v!),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                for (final preset in const [
                  ('1 minute', 1, 0),
                  ('3 minutes', 3, 0),
                  ('5 minutes', 5, 0),
                  ('10 minutes', 10, 0),
                  ('3 minutes + 2 sec./move', 3, 2),
                  ('5 minutes + 2 sec./move', 5, 2),
                ])
                  ListTile(
                    dense: true,
                    title: Text(preset.$1,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => _create(
                        minutes: preset.$2, increment: preset.$3),
                  ),
                for (final a in adverts)
                  ListTile(
                    dense: true,
                    selected: store.myAdvert?.gameId == a.gameId,
                    title: Text(
                        '${a.minutes} + ${a.increment}  ${a.owner} [${a.rating}]',
                        style: TextStyle(
                          color: store.myAdvert?.gameId == a.gameId
                              ? const Color(0xFFE8C87A)
                              : Colors.white,
                        )),
                    subtitle: store.myAdvert?.gameId == a.gameId
                        ? const Text('Your open game - waiting for an opponent',
                            style: TextStyle(color: Colors.white54, fontSize: 11))
                        : null,
                    onTap: () {
                      if (store.myAdvert?.gameId == a.gameId) return;
                      store.joinGame(a.gameId);
                    },
                  ),
                if (adverts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No open games for this kind.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF2A1B10),
              border: Border(top: BorderSide(color: Colors.black26)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ${adverts.length}',
                    style: const TextStyle(color: Colors.white70)),
                Row(
                  children: [
                    _iconButton(Icons.grid_view, 'Create', _customGame),
                    const SizedBox(width: 14),
                    _iconButton(Icons.filter_list, 'Filter', _filter),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFE8C87A), size: 22),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}


