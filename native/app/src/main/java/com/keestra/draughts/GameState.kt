package com.keestra.draughts

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.keestra.draughts.Proto.Id

class MainActivity : ComponentActivity() {

    private lateinit var socket: GameSocket
    private val state = GameState()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        socket = GameSocket("wss://c.keestra.workers.dev")
        state.socket = socket
        socket.onFrame = { bytes -> state.onFrame(bytes) }
        socket.connect()
        setContent { MaterialTheme { App(state) } }
    }

    override fun onDestroy() {
        super.onDestroy()
        socket.close()
    }
}

class GameState {
    lateinit var socket: GameSocket
    var name: String? = null
    var loggedIn = false
    var screen = "login"
    var status: String? = null
    var adverts = listOf<Advert>()
    var myColor = "white"
    var board = Board()
    var myTurn = false
    var selected: Board.Sq? = null
    var legal = listOf<Board.Move>()
    var moveLog = mutableListOf<String>()
    var game: PlayingState? = null

    data class Advert(val id: Long, val owner: String, val minutes: Int, val inc: Int)
    data class PlayingState(val white: String, val black: String, val variant: Int, val minutes: Int, val inc: Int)

    fun onFrame(bytes: ByteArray) {
        val f = Proto.Frame.decode(bytes) ?: return
        when (f.id) {
            Id.LoginA -> {
                val r = f.reader; r.u16le(); name = r.string()
                loggedIn = true; screen = "menu"; status = null
            }
            Id.OpenedGamesN -> {
                val r = f.reader
                val n = r.u16le()
                val list = adverts.toMutableList()
                for (i in 0 until n) {
                    val flags = r.u8(); val id = r.u32le(); r.u8()
                    val owner = r.string() ?: ""
                    r.u16le(); val m = r.u8(); val s = r.u8()
                    if (flags and 1 != 0) r.u8()
                    if (flags and 2 != 0) { val en = r.u8(); if (en == 1) r.string() }
                    list.removeAll { it.id == id }
                    list.add(Advert(id, owner, m, s))
                }
                val rm = r.u16le()
                for (i in 0 until rm) { r.u32le() }
                adverts = list
            }
            Id.ConnectGameA -> {
                val r = f.reader; r.u16le(); r.u8(); val gf = r.u8()
                if (gf == 4) {
                    val gD = r.u8(); val variant = r.u8(); val m = r.u8(); val s = r.u8()
                    val white = r.string() ?: ""; val black = r.string() ?: ""
                    r.uintLE(3); r.uintLE(3)
                    if (gD and 4 != 0) r.u8()
                    val hl = r.u16le(); if (hl > 0) r.bytes(hl)
                    game = PlayingState(white, black, variant, m, s)
                    myColor = if (white == name) "white" else "black"
                    board = Board(); moveLog.clear(); myTurn = myColor == "white"
                    selected = null; legal = emptyList(); screen = "board"
                }
            }
            Id.PlayingGameN -> {
                val r = f.reader; val gf = r.u8()
                if (gf == 4) {
                    val gD = r.u8(); val variant = r.u8(); val m = r.u8(); val s = r.u8()
                    val white = r.string() ?: ""; val black = r.string() ?: ""
                    r.uintLE(3); r.uintLE(3)
                    if (gD and 4 != 0) r.u8()
                    val hl = r.u16le(); if (hl > 0) r.bytes(hl)
                    val move = if (r.remaining() >= 2) r.string() else null
                    if (game == null) game = PlayingState(white, black, variant, m, s)
                    if (move != null) {
                        applyMoveText(move)
                        moveLog.add(move)
                        myTurn = true
                    }
                }
            }
            Id.PlayingGameA -> {
                val r = f.reader; r.u16le(); val ge = r.u8()
                if (ge == 0) { status = "Move not accepted"; myTurn = true }
            }
            Id.ChatN -> {
                val t = f.reader.string()
                if (t != null) status = t
            }
        }
    }

    fun applyMoveText(text: String) {
        val parts = text.split(Regex("[x-]"))
        if (parts.size < 2) return
        val from = Board.sq(parts[0]) ?: return
        val path = parts.drop(1).mapNotNull { Board.sq(it) }
        if (path.isEmpty()) return
        val caps = mutableListOf<Board.Sq>()
        var prev = from
        for (sq in path) {
            if (text.contains('x')) caps.add(Board.Sq((prev.x + sq.x) / 2, (prev.y + sq.y) / 2))
            prev = sq
        }
        board.apply(Board.Move(from, path, caps))
    }

    fun tap(x: Int, y: Int) {
        if (selected != null) {
            val mv = legal.firstOrNull { it.to.x == x && it.to.y == y }
            if (mv != null) {
                socket.send(Proto.playingGameQ(mv.text))
                selected = null; legal = emptyList(); myTurn = false
                return
            }
        }
        val p = board.at(x, y)
        if (p != 0 && myTurn && ((myColor == "white" && (p == 1 || p == 3)) || (myColor == "black" && (p == 2 || p == 4)))) {
            selected = Board.Sq(x, y)
            legal = board.legalMoves().filter { it.from == selected }
        } else {
            selected = null; legal = emptyList()
        }
    }

    fun connect() { socket.connect() }
    fun login(n: String, pw: String, type: Int) {
        socket.send(Proto.loginQ(n, type, pw))
        status = "Connecting..."
    }
    fun subscribeLobby() { socket.send(Proto.openedGamesFeedQ()) }
  fun createGame(minutes: Int, inc: Int, variant: Int = Proto.TOWERS) {
        socket.send(Proto.openedGameQ(variant, minutes, inc, 0, 0, true))
    }
    fun join(id: Long) { socket.send(Proto.connectGameQ(id)) }
}

