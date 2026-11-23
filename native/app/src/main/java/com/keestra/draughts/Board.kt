package com.keestra.draughts

/** Kenyan draughts board model (8x8, men capture both ways, kings fly). */
class Board(var cells: IntArray = initial(), var whiteToMove: Boolean = true) {

    data class Sq(val x: Int, val y: Int) {
        val name: String get() = "abcdefgh"[x] + (8 - y).toString()
    }

    data class Move(val from: Sq, val path: List<Sq>, val captures: List<Sq>) {
        val to: Sq get() = path.last()
        val isCapture: Boolean get() = captures.isNotEmpty()
        val text: String get() {
            val sb = StringBuilder(from.name)
            path.forEachIndexed { i, sq -> sb.append(if (i == 0 && !isCapture) '-' else 'x').append(sq.name) }
            return sb.toString()
        }
    }

    fun at(x: Int, y: Int) = cells[y * 8 + x]
    fun set(x: Int, y: Int, v: Int) { cells[y * 8 + x] = v }
    fun inside(x: Int, y: Int) = x in 0..7 && y in 0..7
    fun isWhite(p: Int) = p == 1 || p == 3
    fun isBlack(p: Int) = p == 2 || p == 4
    fun isKing(p: Int) = p == 3 || p == 4
    fun sameColor(a: Int, b: Int) = (isWhite(a) && isWhite(b)) || (isBlack(a) && isBlack(b))

    fun clone(): Board = Board(cells.copyOf(), whiteToMove)

    fun legalMoves(): List<Move> {
        val caps = captureMoves(whiteToMove)
        if (caps.isNotEmpty()) return caps
        return quietMoves(whiteToMove)
    }

    fun quietMoves(white: Boolean): List<Move> {
        val out = mutableListOf<Move>()
        for (y in 0..7) for (x in 0..7) {
            val p = at(x, y)
            if (p == 0 || isWhite(p) != white) continue
            val dirs = if (isKing(p)) listOf(1 to 1, 1 to -1, -1 to 1, -1 to -1)
            else if (white) listOf(1 to -1, -1 to -1) else listOf(1 to 1, -1 to 1)
            for ((dx, dy) in dirs) {
                if (isKing(p)) {
                    var d = 1
                    while (true) {
                        val nx = x + dx * d; val ny = y + dy * d
                        if (!inside(nx, ny) || at(nx, ny) != 0) break
                        out.add(Move(Sq(x, y), listOf(Sq(nx, ny)), emptyList()))
                        d++
                    }
                } else {
                    val nx = x + dx; val ny = y + dy
                    if (inside(nx, ny) && at(nx, ny) == 0) out.add(Move(Sq(x, y), listOf(Sq(nx, ny)), emptyList()))
                }
            }
        }
        return out
    }

    fun captureMoves(white: Boolean): List<Move> {
        val out = mutableListOf<Move>()
        for (y in 0..7) for (x in 0..7) {
            val p = at(x, y)
            if (p == 0 || isWhite(p) != white) continue
            for ((dx, dy) in listOf(1 to 1, 1 to -1, -1 to 1, -1 to -1)) {
                val mx = x + dx; val my = y + dy
                if (!inside(mx, my)) continue
                val mid = at(mx, my)
                if (mid == 0 || sameColor(mid, p)) continue
                val lx = mx + dx; val ly = my + dy
                if (!inside(lx, ly) || at(lx, ly) != 0) continue
                out.add(Move(Sq(x, y), listOf(Sq(lx, ly)), listOf(Sq(mx, my))))
            }
        }
        return out
  }

    fun apply(m: Move): Boolean {
        val piece = at(m.from.x, m.from.y)
        if (piece == 0) return false
        set(m.from.x, m.from.y, 0)
        var prev = m.from
        for (sq in m.path) {
            if (m.isCapture) {
                set((prev.x + sq.x) / 2, (prev.y + sq.y) / 2, 0)
            }
            prev = sq
        }
        var landed = piece
        if (piece == 1 && m.to.y == 0) landed = 3
        if (piece == 2 && m.to.y == 7) landed = 4
        set(m.to.x, m.to.y, landed)
        whiteToMove = !whiteToMove
        return true
    }

    companion object {
        const val EMPTY = 0
        const val WHITE_MAN = 1
        const val BLACK_MAN = 2
        const val WHITE_KING = 3
        const val BLACK_KING = 4

        fun initial(): IntArray {
            val b = IntArray(64)
            for (y in 0..7) for (x in 0..7) {
                if ((x + y) % 2 != 1) continue
                if (y < 3) b[y * 8 + x] = BLACK_MAN
                if (y > 4) b[y * 8 + x] = WHITE_MAN
            }
            return b
        }

        fun parse(text: String): Board {
            val b = Board()
            text.split(RegExp("[x-]")).forEachIndexed { i, s ->
                if (i == 0) return@forEachIndexed
                val sq = sq(s) ?: return@forEachIndexed
                // apply as a quiet move for parsing purposes
            }
            return b
        }

        fun sq(s: String): Sq? {
            if (s.length < 2) return null
            val x = s[0] - 'a'
            val y = 8 - s[1].digitToInt()
            if (x !in 0..7 || y !in 0..7) return null
            return Sq(x, y)
        }
    }
}