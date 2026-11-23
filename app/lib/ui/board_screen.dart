import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../engine/board.dart';
import '../state/game_store.dart';
import 'board_painter.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  Square? _selected;
  List<Move> _legal = [];
  bool _flipped = false;

  Draughts? get _board => context.read<GameStore>().board;

  void _onTap(Size boardSize, Offset pos) {
    final board = _board;
    if (board == null) return;
    final cell = boardSize.width / 8;
    var x = (pos.dx / cell).floor();
    var y = (pos.dy / cell).floor();
    if (x < 0 || x > 7 || y < 0 || y > 7) return;
    if (_flipped) {
      x = 7 - x;
      y = 7 - y;
    }
    final sq = Square(x, y);

    // If a piece is selected and the tapped square is a legal target, move.
    if (_selected != null) {
      final move = _legal.firstWhere(
        (m) => m.to.x == x && m.to.y == y,
        orElse: () => Move(_selected!, const [], const []),
      );
      if (move.path.isNotEmpty && move.from == _selected) {
        context.read<GameStore>().sendMove(move.text);
        setState(() {
          _selected = null;
          _legal = [];
        });
        return;
      }
    }

    // Otherwise select one of my pieces.
    final p = board.at(x, y);
    final store = context.read<GameStore>();
    final mine = store.myColor == 'white'
        ? (p == Piece.whiteMan || p == Piece.whiteKing)
        : (p == Piece.blackMan || p == Piece.blackKing);
    if (mine && store.myTurn) {
      final all = board.legalMoves().where((m) => m.from == sq).toList();
      setState(() {
        _selected = sq;
        _legal = all;
      });
    } else {
      setState(() {
        _selected = null;
        _legal = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GameStore>();
    final board = store.board;
    final game = store.game;

    return Scaffold(
      backgroundColor: const Color(0xFF1E140C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1B10),
        title: Text(
          game == null
              ? 'Keestra Draughts'
              : '${game.white}  vs  ${game.black}',
          style: const TextStyle(color: Color(0xFFE8C87A), fontSize: 15),
        ),
      ),
      body: board == null
          ? const Center(child: Text('No game', style: TextStyle(color: Colors.white)))
          : Column(
              children: [
                if (game != null)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${game.minutes} + ${game.increment}   •   '
                      '${store.myTurn ? 'Your turn' : "Opponent's turn"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final size = constraints.biggest.shortestSide;
                          return GestureDetector(
                            onTapUp: (d) => _onTap(Size(size, size), d.localPosition),
                            child: CustomPaint(
                              size: Size(size, size),
                              painter: BoardPainter(
                                board: board,
                                selected: _selected,
                                legalTargets:
                                    _legal.map((m) => m.to).toSet().toList(),
                                flip: _flipped,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A1B10),
                    border: Border(top: BorderSide(color: Colors.black26)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _action(Icons.swap_vert, 'Flip', () {
                        setState(() => _flipped = !_flipped);
                      }),
                      _action(Icons.chat, 'Chat', _showChat),
                      _action(Icons.info, 'Info', () {}),
                      _action(Icons.menu, 'Menu', () {
                        Navigator.of(context).pop();
                      }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showChat() {
    final store = context.read<GameStore>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1B10),
        title: const Text('Chat', style: TextStyle(color: Color(0xFFE8C87A))),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: store.chat
                .map((m) => Text(m, style: const TextStyle(color: Colors.white)))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
