package com.keestra.draughts

import android.graphics.BitmapFactory
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Palette sampled from the original APK screenshots (emu1: login).
private val Leather = Color(0xFFB89272)        // light tan leather
private val LeatherDark = Color(0xFF9A7A5C)
private val Cream = Color(0xFFFBE6B8)
private val FieldBg = Color(0xFFF2E8D8)        // near-white input box
private val FieldText = Color(0xFF2A1A10)
private val LoginRed = Color(0xFFB02418)       // red login button
private val GuestGrey = Color(0xFF9E9E9E)      // grey guest button
private val Gold = Color(0xFFE8C87A)
private val LinkGrey = Color(0xFF8A8A8A)

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

/** Leather background with a dark overlay, like the original. */
@Composable
private fun LeatherBackground(content: @Composable () -> Unit) {
    val context = LocalContext.current
    val bitmap = remember {
        try {
            context.assets.open("textures/leather.png").use { BitmapFactory.decodeStream(it) }
        } catch (e: Exception) {
            null
        }
    }
    Box(modifier = Modifier.fillMaxSize()) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        } else {
            Box(Modifier.fillMaxSize().background(Leather))
        }
        Box(Modifier.fillMaxSize().background(Color.White.copy(alpha = 0.05f)))
        content()
    }
}

/** Brown/red gradient button with a gold border, like the original. */
@Composable
private fun KeestraButton(
    text: String,
    modifier: Modifier = Modifier,
    bg: Color = LoginRed,
    fg: Color = Cream,
    onClick: () -> Unit
) {
    Box(
        modifier = modifier
            .height(46.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(bg)
            .border(1.dp, Gold.copy(alpha = 0.6f), RoundedCornerShape(6.dp))
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(text, color = fg, fontSize = 16.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun KeestraField(
    label: String,
    value: String,
    onValue: (String) -> Unit,
    modifier: Modifier = Modifier,
    password: Boolean = false
) {
    Column(modifier = modifier) {
        Text(label, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(2.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(46.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(FieldBg)
                .border(1.dp, Gold.copy(alpha = 0.5f), RoundedCornerShape(6.dp))
                .padding(10.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            BasicTextField(
                value = value,
                onValueChange = onValue,
                singleLine = true,
                textStyle = TextStyle(color = FieldText, fontSize = 15.sp),
                visualTransformation = if (password) PasswordVisualTransformation() else VisualTransformation.None,
                cursorBrush = androidx.compose.ui.graphics.SolidColor(FieldText),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun LoginScreen(state: GameState) {
    var name by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    var mode by remember { mutableStateOf(Proto.LOGIN) }

    LeatherBackground {
        Column(
            modifier = Modifier.fillMaxSize().padding(start = 24.dp, end = 24.dp, top = 72.dp)
        ) {
            // Login field (matches emu1: label above a near-white box)
            KeestraField("Login:", name, { name = it }, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(18.dp))
            KeestraField("Password:", pass, { pass = it }, password = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(26.dp))
            // Red login button
            KeestraButton("Login", modifier = Modifier.fillMaxWidth()) {
                state.login(name, pass, mode)
            }
            Spacer(Modifier.height(14.dp))
            // Forgot password link
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                Text(
                    "Forgot your password?",
                    color = Color.White,
                    fontSize = 13.sp,
                    modifier = Modifier.clickable { /* TODO: reset flow */ }
                )
            }
            Spacer(Modifier.height(26.dp))
            // Guest button (grey)
            KeestraButton(
                "Guest",
                modifier = Modifier.fillMaxWidth(),
                bg = GuestGrey,
                fg = Color.White
            ) {
                state.login("", "", Proto.GUEST)
            }
            Spacer(Modifier.height(12.dp))
            // mode switch (registration / registered) kept subtle
            Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                _radio("Registered user", mode == Proto.LOGIN) { mode = Proto.LOGIN }
                Spacer(Modifier.width(18.dp))
                _radio("Guest", mode == Proto.GUEST) { mode = Proto.GUEST }
                Spacer(Modifier.width(18.dp))
                _radio("Registration", mode == Proto.NEW_PLAYER) { mode = Proto.NEW_PLAYER }
            }
            if (state.status != null) {
                Spacer(Modifier.height(14.dp))
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Text(state.status!!, color = Color(0xFFFFA726), fontSize = 12.sp)
                }
            }
        }
    }
}

@Composable
private fun _radio(label: String, selected: Boolean, onSelect: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.clickable { onSelect() }) {
        Canvas(modifier = Modifier.size(14.dp)) {
            drawCircle(Color(0xFF2A1710), 7f)
            drawCircle(Color.White.copy(alpha = if (selected) 1f else 0.5f), 7f, style = Stroke(width = 1.5f))
            if (selected) drawCircle(Color.White, 3.5f)
        }
        Spacer(Modifier.width(4.dp))
        Text(label, color = Color.White, fontSize = 11.sp)
    }
}

@Composable
private fun MenuScreen(state: GameState) {
    LeatherBackground {
        Column(
            modifier = Modifier.fillMaxSize().padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(40.dp))
            Text("Draughts by Keestra", color = Cream, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text("Signed in: ${state.name ?: "?"}", color = Cream.copy(alpha = 0.6f), fontSize = 11.sp)
            Spacer(Modifier.height(28.dp))
            listOf("Play", "Started games", "User profile", "Players", "Settings").forEach { label ->
                KeestraButton(label, modifier = Modifier.fillMaxWidth().padding(4.dp)) {
                    if (label == "Play") { state.screen = "lobby"; state.subscribeLobby() }
                }
            }
        }
    }
}

@Composable
private fun LobbyScreen(state: GameState) {
    Column(modifier = Modifier.fillMaxSize().background(LeatherDark)) {
        Text("Opened Games", color = Cream, fontSize = 18.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(14.dp))
        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Kind of checkers:", color = Cream.copy(alpha = 0.7f), fontSize = 11.sp)
            Spacer(Modifier.width(6.dp))
            Text("Kenyan Nairobi", color = Cream, fontSize = 11.sp)
        }
        Divider(color = Color.Black.copy(alpha = 0.3f))
        Column(modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            listOf(1 to 0, 3 to 0, 5 to 0, 10 to 0, 3 to 2, 5 to 2).forEach { (m, s) ->
                Text("${m} minutes${if (s > 0) " + $s sec./move" else ""}",
                    color = Cream, modifier = Modifier.fillMaxWidth().clickable { state.createGame(m, s) }.padding(14.dp))
                Divider(color = Color.Black.copy(alpha = 0.3f))
            }
            state.adverts.forEach { a ->
                Text("${a.minutes} + ${a.inc}  ${a.owner}",
                    color = if (a.owner == state.name) Gold else Cream,
                    modifier = Modifier.fillMaxWidth().clickable { state.join(a.id) }.padding(14.dp))
                Divider(color = Color.Black.copy(alpha = 0.3f))
            }
        }
        Row(modifier = Modifier.fillMaxWidth().background(Color(0xFF3A2416)).padding(10.dp)) {
            Text("Total: ${state.adverts.size}", color = Cream.copy(alpha = 0.8f), modifier = Modifier.weight(1f))
            TextButton(onClick = { state.createGame(3, 0) }) { Text("Create", color = Cream) }
        }
    }
}

@Composable
private fun BoardScreen(state: GameState) {
    Column(modifier = Modifier.fillMaxSize().background(LeatherDark)) {
        Text("${state.game?.white ?: "?"}  vs  ${state.game?.black ?: "?"}",
            color = Cream, fontSize = 14.sp, modifier = Modifier.padding(10.dp))
        Text(if (state.myTurn) "Your turn" else "Opponent's turn",
            color = Cream.copy(alpha = 0.7f), fontSize = 11.sp, modifier = Modifier.padding(10.dp))
        Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            Canvas(
                modifier = Modifier.fillMaxWidth().aspectRatio(1f).padding(6.dp)
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
                drawRect(Color(0xFF7A4A22))
                for (y in 0..7) for (x in 0..7) if ((x + y) % 2 == 1) {
                    drawRect(Color(0xFFE6CFA3), topLeft = Offset(x * cell, y * cell), size = androidx.compose.ui.geometry.Size(cell, cell))
                }
                state.selected?.let { sq ->
                    drawRect(Color(0xFFFFD54F).copy(alpha = 0.45f), topLeft = Offset(sq.x * cell, sq.y * cell), size = androidx.compose.ui.geometry.Size(cell, cell))
                }
                for (y in 0..7) for (x in 0..7) {
                    val p = state.board.at(x, y)
                    if (p == 0) continue
                    val white = p == 1 || p == 3
                    val cx = x * cell + cell / 2; val cy = y * cell + cell / 2
                    drawCircle(if (white) Color(0xFFF2F2F2) else Color(0xFF1B1B1B), cell * 0.38f, center = Offset(cx, cy))
                    drawCircle(if (white) Color(0xFFB0B0B0) else Color.Black, cell * 0.38f, center = Offset(cx, cy), style = Stroke(width = 2f))
                }
            }
        }
        state.status?.let { Text(it, color = Color(0xFFFFA726), modifier = Modifier.padding(10.dp)) }
    }
}





