package com.keestra.draughts

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

private val Brown = Color(0xFF6B4A2B)
private val Gold = Color(0xFFE8C87A)
private val Dark = Color(0xFF1E140C)

@Composable
fun App(state: GameState) {
    when (state.screen) {
        "login" -> LoginScreen(state)
        "menu" -> MenuScreen(state)
        "lobby" -> LobbyScreen(state)
        "board" -> BoardScreen(state)
        else -> LoginScreen(state)
    }
}

@Composable
private fun LoginScreen(state: GameState) {
    var name by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    Column(
        modifier = Modifier.fillMaxSize().background(Dark).padding(24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Text("Keestra Draughts", color = Gold, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Text("Kenyan Nairobi draughts", color = Color.White.copy(alpha = 0.6f), fontSize = 13.sp)
        Spacer(Modifier.height(24.dp))
        OutlinedTextField(name, { name = it }, label = { Text("Login") }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(pass, { pass = it }, label = { Text("Password") }, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(20.dp))
        Button(onClick = { state.login(name, pass, Proto.LOGIN) }, modifier = Modifier.fillMaxWidth()) { Text("Login") }
        OutlinedButton(onClick = { state.login("", "", Proto.GUEST) }, modifier = Modifier.fillMaxWidth()) { Text("Guest") }
        if (state.status != null) Text(state.status!!, color = Color(0xFFFFA726))
    }
}

@Composable
private fun MenuScreen(state: GameState) {
    Column(
        modifier = Modifier.fillMaxSize().background(Dark).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(32.dp))
        Text("Keestra Draughts", color = Gold, fontSize = 26.sp, fontWeight = FontWeight.Bold)
        Text("Signed in: ${state.name ?: "?"}", color = Color.White.copy(alpha = 0.6f), fontSize = 12.sp)
        Spacer(Modifier.height(24.dp))
        listOf("Play", "Started games", "User profile", "Players").forEach { label ->
            Button(onClick = { if (label == "Play") { state.screen = "lobby"; state.subscribeLobby() } },
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) { Text(label) }
        }
    }
}

@Composable
private fun LobbyScreen(state: GameState) {
    var minutes by remember { mutableStateOf(3) }
    Column(modifier = Modifier.fillMaxSize().background(Dark)) {
        Text("Opened Games", color = Gold, fontSize = 20.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(16.dp))
        Row(modifier = Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Kind of checkers:", color = Color.White.copy(alpha = 0.7f), fontSize = 12.sp)
            Spacer(Modifier.width(8.dp))
            Text("Kenyan Nairobi", color = Color.White, fontSize = 12.sp)
        }
        Divider()
        Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            listOf(1 to 0, 3 to 0, 5 to 0, 10 to 0, 3 to 2, 5 to 2).forEach { (m, s) ->
                Text("${m} minutes${if (s > 0) " + $s sec./move" else ""}",
                    color = Color.White, modifier = Modifier.fillMaxWidth().clickable {
                        minutes = m; state.createGame(m, s)
                    }.padding(16.dp))
                Divider()
            }
            state.adverts.forEach { a ->
                Text("${a.minutes} + ${a.inc}  ${a.owner}",
                    color = if (a.owner == state.name) Gold else Color.White,
                    modifier = Modifier.fillMaxWidth().clickable { state.join(a.id) }.padding(16.dp))
                Divider()
            }
        }
        Row(modifier = Modifier.fillMaxWidth().background(Brown).padding(12.dp)) {
            Text("Total: ${state.adverts.size}", color = Color.White, modifier = Modifier.weight(1f))
            TextButton(onClick = { state.createGame(minutes, 0) }) { Text("Create", color = Color.White) }
        }
    }
}

@Composable
private fun BoardScreen(state: GameState) {
    Column(modifier = Modifier.fillMaxSize().background(Dark)) {
        Text("${state.game?.white ?: "?"}  vs  ${state.game?.black ?: "?"}",
            color = Gold, fontSize = 15.sp, modifier = Modifier.padding(12.dp))
        Text(if (state.myTurn) "Your turn" else "Opponent's turn",
            color = Color.White.copy(alpha = 0.7f), fontSize = 12.sp, modifier = Modifier.padding(horizontal = 12.dp))
        Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            Canvas(
                modifier = Modifier.fillMaxWidth().aspectRatio(1f).padding(8.dp)
                    .pointerInput(Unit) {
                        awaitPointerEventScope {
                            while (true) {
                                val e = awaitPointerEvent()
                                val pos = e.changes.first().position
                                val cell = minOf(size.width, size.height) / 8f
                                val x = (pos.x / cell).toInt().coerceIn(0, 7)
                                val y = (pos.y / cell).toInt().coerceIn(0, 7)
                                state.tap(x, y)
                            }
                        }
                    }
            ) {
                val cell = minOf(size.width, size.height) / 8f
                val light = Color(0xFFE6CFA3); val darkC = Color(0xFF7A4A22)
                drawRect(darkC)
                for (y in 0..7) for (x in 0..7) if ((x + y) % 2 == 1) {
                    drawRect(light, topLeft = Offset(x * cell, y * cell), size = androidx.compose.ui.geometry.Size(cell, cell))
                }
                state.selected?.let { sq ->
                    drawRect(Color(0xFFFFD54F).copy(alpha = 0.45f),
                        topLeft = Offset(sq.x * cell, sq.y * cell), size = androidx.compose.ui.geometry.Size(cell, cell))
                }
                for (y in 0..7) for (x in 0..7) {
                    val p = state.board.at(x, y)
                    if (p == 0) continue
                    val white = p == 1 || p == 3
                    val cx = x * cell + cell / 2; val cy = y * cell + cell / 2
                    drawCircle(if (white) Color(0xFFF2F2F2) else Color(0xFF1B1B1B), cell * 0.38f, center = Offset(cx, cy))
                    drawCircle(if (white) Color(0xFFB0B0B0) else Color.Black, cell * 0.38f, center = Offset(cx, cy),
                        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2f))
                }
            }
        }
        state.status?.let { Text(it, color = Color(0xFFFFA726), modifier = Modifier.padding(12.dp)) }
    }
}
