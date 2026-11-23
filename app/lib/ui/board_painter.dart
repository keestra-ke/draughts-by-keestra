import 'package:flutter/material.dart';
import '../engine/board.dart';

class BoardPainter extends CustomPainter {
  final Draughts board;
  final Square? selected;
  final List<Square> legalTargets;
  final bool flip;

  BoardPainter({
    required this.board,
    this.selected,
    this.legalTargets = const [],
    this.flip = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    final light = Paint()..color = const Color(0xFFE6CFA3);
    final dark = Paint()..color = const Color(0xFF7A4A22);
    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(boardRect, dark);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        if ((x + y) % 2 == 1) {
          final dx = flip ? 7 - x : x;
          final dy = flip ? 7 - y : y;
          canvas.drawRect(
              Rect.fromLTWH(dx * cell, dy * cell, cell, cell), light);
        }
      }
    }

    // Selection + legal target markers.
    if (selected != null) {
      final s = _screen(selected!, flip);
      canvas.drawRect(
          Rect.fromLTWH(s.dx * cell, s.dy * cell, cell, cell),
          Paint()..color = Colors.yellow.withOpacity(0.45));
    }
    for (final t in legalTargets) {
      final s = _screen(t, flip);
      canvas.drawCircle(
          Offset(s.dx * cell + cell / 2, s.dy * cell + cell / 2),
          cell * 0.12,
          Paint()..color = Colors.green.withOpacity(0.75));
    }

    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final p = board.at(x, y);
        if (p == Piece.empty) continue;
        final s = _screen(Square(x, y), flip);
        _paintPiece(canvas, s.dx * cell + cell / 2, s.dy * cell + cell / 2,
            cell * 0.38, p);
      }
    }
  }

  void _paintPiece(Canvas canvas, double cx, double cy, double r, int p) {
    final white = p == Piece.whiteMan || p == Piece.whiteKing;
    final base = white ? const Color(0xFFF2F2F2) : const Color(0xFF1B1B1B);
    final edge = white ? const Color(0xFFB0B0B0) : const Color(0xFF000000);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [base, white ? const Color(0xFFD8D8D8) : const Color(0xFF333333)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, paint);
    canvas.drawCircle(
        Offset(cx, cy), r, Paint()..style = PaintingStyle.stroke..color = edge..strokeWidth = 2);
    if (p == Piece.whiteKing || p == Piece.blackKing) {
      final crown = Paint()
        ..color = white ? const Color(0xFF8A6A20) : const Color(0xFFE8C87A)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(cx - r * 0.5, cy + r * 0.25)
        ..lineTo(cx - r * 0.5, cy - r * 0.15)
        ..lineTo(cx - r * 0.2, cy + r * 0.05)
        ..lineTo(cx, cy - r * 0.35)
        ..lineTo(cx + r * 0.2, cy + r * 0.05)
        ..lineTo(cx + r * 0.5, cy - r * 0.15)
        ..lineTo(cx + r * 0.5, cy + r * 0.25)
        ..close();
      canvas.drawPath(path, crown);
    }
  }

  _Screen _screen(Square s, bool flip) {
    final dx = flip ? 7 - s.x : s.x;
    final dy = flip ? 7 - s.y : s.y;
    return _Screen(dx, dy);
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) =>
      old.board != board || old.selected != selected || old.flip != flip;
}

class _Screen {
  final int dx, dy;
  const _Screen(this.dx, this.dy);
}