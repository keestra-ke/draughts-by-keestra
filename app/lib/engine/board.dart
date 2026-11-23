import 'dart:typed_data';

/// Piece codes.
class Piece {
  static const empty = 0;
  static const whiteMan = 1;
  static const blackMan = 2;
  static const whiteKing = 3;
  static const blackKing = 4;
}

class Square {
  final int x, y;
  const Square(this.x, this.y);
  String get name => '${'abcdefgh'[x]}${8 - y}';
  static Square? parse(String s) {
    if (s.length < 2) return null;
    final x = s.codeUnitAt(0) - 97;
    final y = 8 - int.parse(s[1]);
    if (x < 0 || x > 7 || y < 0 || y > 7) return null;
    return Square(x, y);
  }

  @override
  bool operator ==(Object other) =>
      other is Square && other.x == x && other.y == y;

  @override
  int get hashCode => x * 31 + y;
}

class Move {
  final Square from;
  final List<Square> path; // landing squares in order
  final List<Square> captures;
  const Move(this.from, this.path, this.captures);

  Square get to => path.last;
  bool get isCapture => captures.isNotEmpty;
  String get text {
    final sb = StringBuffer('${from.name}');
    for (var i = 0; i < path.length; i++) {
      sb.write(i == 0 && !isCapture ? '-' : 'x');
      sb.write(path[i].name);
    }
    return sb.toString();
  }
}

/// Kenyan Nairobi draughts engine (8x8, men capture both directions,
/// kings fly, compulsory capture, multi-chain, promotion, huffing claims).
class Draughts {
  final Uint8List board;
  bool whiteToMove;
  bool huffing;

  Draughts({Uint8List? board, this.whiteToMove = true, this.huffing = true})
      : board = board ?? initialBoard();

  static Uint8List initialBoard() {
    final b = Uint8List(64);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if ((x + y) % 2 != 1) continue;
        if (y < 3) b[y * 8 + x] = Piece.blackMan;
        if (y > 4) b[y * 8 + x] = Piece.whiteMan;
      }
    }
    return b;
  }

  int at(int x, int y) => board[y * 8 + x];
  void setAt(int x, int y, int v) => board[y * 8 + x] = v;
  bool inside(int x, int y) => x >= 0 && x < 8 && y >= 0 && y < 8;

  bool isWhite(int p) => p == Piece.whiteMan || p == Piece.whiteKing;
  bool isBlack(int p) => p == Piece.blackMan || p == Piece.blackKing;
  bool isKing(int p) => p == Piece.whiteKing || p == Piece.blackKing;
  bool sameColor(int a, int b) =>
      (isWhite(a) && isWhite(b)) || (isBlack(a) && isBlack(b));

  bool get whiteWins => _count(Piece.whiteMan) + _count(Piece.whiteKing) == 0;
  bool get blackWins => _count(Piece.blackMan) + _count(Piece.blackKing) == 0;

  int _count(int p) {
    var n = 0;
    for (final v in board) {
      if (v == p) n++;
    }
    return n;
  }

  /// All legal moves for the side to move.
  List<Move> legalMoves() {
    final captures = _captureMoves(whiteToMove);
    if (captures.isNotEmpty) return captures;
    // Huffing: quiet moves are offered beside a capture; the opponent may claim.
    if (huffing) return _quietMoves(whiteToMove);
    return const [];
  }

  List<Move> _quietMoves(bool white) {
    final out = <Move>[];
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final p = at(x, y);
        if (p == Piece.empty) continue;
        if (white != isWhite(p)) continue;
        final dirs = isKing(p)
            ? const [[1, 1], [1, -1], [-1, 1], [-1, -1]]
            : (white
                ? const [[1, -1], [-1, -1]]
                : const [[1, 1], [-1, 1]]);
        for (final d in dirs) {
          if (isKing(p)) {
            for (var step = 1; step < 8; step++) {
              final nx = x + d[0] * step;
              final ny = y + d[1] * step;
              if (!inside(nx, ny)) break;
              if (at(nx, ny) != Piece.empty) break;
              out.add(Move(Square(x, y), [Square(nx, ny)], const []));
            }
          } else {
            final nx = x + d[0];
            final ny = y + d[1];
            if (!inside(nx, ny)) continue;
            if (at(nx, ny) == Piece.empty) {
              out.add(Move(Square(x, y), [Square(nx, ny)], const []));
            }
          }
        }
      }
    }
    return out;
  }

  List<Move> _captureMoves(bool white) {
    final out = <Move>[];
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final p = at(x, y);
        if (p == Piece.empty) continue;
        if (white != isWhite(p)) continue;
        final piece = p;
        final dirs = const [[1, 1], [1, -1], [-1, 1], [-1, -1]];
        for (final d in dirs) {
          if (isKing(piece)) {
            _kingCaptures(x, y, d[0], d[1], piece, [Square(x, y)], const [], out);
          } else {
            final mx = x + d[0];
            final my = y + d[1];
            if (!inside(mx, my)) continue;
            final mid = at(mx, my);
            if (mid == Piece.empty || sameColor(mid, piece)) continue;
            final lx = mx + d[0];
            final ly = my + d[1];
            if (!inside(lx, ly)) continue;
            if (at(lx, ly) != Piece.empty) continue;
            _manCaptures(x, y, d[0], d[1], piece, [Square(lx, ly)],
                [Square(mx, my)], out);
          }
        }
      }
    }
    return out;
  }

  void _manCaptures(int x, int y, int dx, int dy, int piece, List<Square> path,
      List<Square> captures, List<Move> out) {
    final lx = x + dx * 2;
    final ly = y + dy * 2;
    if (inside(lx, ly) && at(lx, ly) == Piece.empty) {
      // Continue the chain from the landing square.
      final mx = x + dx;
      final my = y + dy;
      final b = Uint8List.fromList(board);
      b[y * 8 + x] = Piece.empty;
      b[my * 8 + mx] = Piece.empty;
      b[ly * 8 + lx] = piece;
      final sub = Draughts(board: b, whiteToMove: whiteToMove, huffing: huffing);
      final more = sub._captureMovesFrom(lx, ly, piece);
      if (more.isEmpty) {
        out.add(Move(Square(x, y), List.of(path), List.of(captures)));
      } else {
        for (final m in more) {
          out.add(Move(Square(x, y), [path.first, ...m.path],
              [captures.first, ...m.captures]));
        }
      }
    }
  }

  List<Move> _captureMovesFrom(int x, int y, int piece) {
    final out = <Move>[];
    for (final d in const [[1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      final mx = x + d[0];
      final my = y + d[1];
      if (!inside(mx, my)) continue;
      final mid = at(mx, my);
      if (mid == Piece.empty || sameColor(mid, piece)) continue;
      final lx = mx + d[0];
      final ly = my + d[1];
      if (!inside(lx, ly)) continue;
      if (at(lx, ly) != Piece.empty) continue;
      _manCaptures(x, y, d[0], d[1], piece, [Square(lx, ly)], [Square(mx, my)], out);
    }
    return out;
  }

  void _kingCaptures(int x, int y, int dx, int dy, int piece, List<Square> path,
      List<Square> captures, List<Move> out) {
    var mx = x + dx;
    var my = y + dy;
    while (inside(mx, my) && at(mx, my) == Piece.empty) {
      mx += dx;
      my += dy;
    }
    if (!inside(mx, my)) return;
    final mid = at(mx, my);
    if (sameColor(mid, piece)) return;
    var lx = mx + dx;
    var ly = my + dy;
    while (inside(lx, ly) && at(lx, ly) == Piece.empty) {
      out.add(Move(Square(x, y), [Square(lx, ly)], [Square(mx, my)]));
      lx += dx;
      ly += dy;
    }
  }

  /// Apply a move. Returns true on success.
  bool apply(Move m) {
    final piece = at(m.from.x, m.from.y);
    if (piece == Piece.empty) return false;
    setAt(m.from.x, m.from.y, Piece.empty);
    Square prev = m.from;
    for (final sq in m.path) {
      if (m.isCapture) {
        final cx = (prev.x + sq.x) ~/ 2;
        final cy = (prev.y + sq.y) ~/ 2;
        setAt(cx, cy, Piece.empty);
      }
      prev = sq;
    }
    var landed = piece;
    if (piece == Piece.whiteMan && m.to.y == 0) landed = Piece.whiteKing;
    if (piece == Piece.blackMan && m.to.y == 7) landed = Piece.blackKing;
    setAt(m.to.x, m.to.y, landed);
    whiteToMove = !whiteToMove;
    return true;
  }

  Draughts clone() => Draughts(
      board: Uint8List.fromList(board),
      whiteToMove: whiteToMove,
      huffing: huffing);
}