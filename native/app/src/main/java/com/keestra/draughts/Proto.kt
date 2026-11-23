package com.keestra.draughts

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Binary protocol codec for the Checkersland/Keestra wire format. */
object Proto {
    const val MAGIC = 0x39

    object Id {
        const val ChatQ = 0
        const val ChatN = 1
        const val StateN = 2
        const val PlayersN = 3
        const val OpenedGamesN = 4
        const val PlayingGameN = 5
        const val ConnectGameQ = 14
        const val ConnectGameA = 15
        const val LoginQ = 22
        const val LoginA = 23
        const val OpenedGameQ = 24
        const val OpenedGameA = 25
        const val NetworkDataListeningQ = 26
        const val NetworkDataListeningA = 27
        const val PingQ = 28
        const val PingA = 29
        const val PlayingGameQ = 30
        const val PlayingGameA = 31
    }

    class Reader(bytes: ByteArray) {
        private val bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var pos = 0
        fun remaining() = bb.remaining()
        fun u8(): Int { val v = bb.get().toInt() and 0xFF; pos++; return v }
        fun u16le(): Int { val v = bb.short.toInt() and 0xFFFF; pos += 2; return v }
        fun u32le(): Long { val v = bb.int.toLong() and 0xFFFFFFFF; pos += 4; return v }
        fun uintLE(n: Int): Long { var v = 0L; for (i in 0 until n) v = v or (u8().toLong() shl (8 * i)); return v }
        fun bytes(n: Int): ByteArray { val b = ByteArray(n); bb.get(b); pos += n; return b }
        fun string(): String? {
            val len = u16le()
            if (len == 0xFFFF) return null
            return String(bytes(len), Charsets.UTF_8)
        }
    }

    class Writer {
        private val out = ByteArrayOutputStream()
        fun u8(v: Int) { out.write(v and 0xFF) }
        fun u16le(v: Int) { u8(v); u8(v ushr 8) }
        fun u32le(v: Long) { for (i in 0..3) u8((v ushr (8 * i)).toInt()) }
        fun uintLE(v: Long, n: Int) { for (i in 0 until n) u8((v ushr (8 * i)).toInt()) }
        fun bytes(b: ByteArray) { out.write(b) }
        fun string(s: String?) {
            if (s == null || s.isEmpty()) { u16le(0xFFFF); return }
            val raw = s.toByteArray(Charsets.UTF_8)
            u16le(raw.size)
            out.write(raw)
        }
        fun bool(v: Boolean) { u8(if (v) 1 else 0) }
        fun toBytes(): ByteArray = out.toByteArray()
    }

    class Frame(val id: Int, val reader: Reader, val bytes: ByteArray) {
        val name: String get() = names[id] ?: "id$id"
        companion object {
            fun decode(raw: ByteArray): Frame? {
                if (raw.size < 2) return null
                if (raw[0].toInt() and 0xFF != MAGIC) return null
                return Frame(raw[1].toInt() and 0xFF, Reader(raw), raw)
            }
        }
    }

    fun build(id: Int, w: Writer.() -> Unit): ByteArray {
        val wr = Writer(); wr.w()
        val payload = wr.toBytes()
        val out = ByteArray(2 + payload.size)
        out[0] = MAGIC.toByte()
        out[1] = id.toByte()
        System.arraycopy(payload, 0, out, 2, payload.size)
        return out
    }

    val names = mapOf(
        Id.ChatQ to "ChatQ", Id.ChatN to "ChatN", Id.StateN to "StateN",
        Id.PlayersN to "PlayersN", Id.OpenedGamesN to "OpenedGamesN",
        Id.PlayingGameN to "PlayingGameN", Id.ConnectGameQ to "ConnectGameQ",
        Id.ConnectGameA to "ConnectGameA", Id.LoginQ to "LoginQ", Id.LoginA to "LoginA",
        Id.OpenedGameQ to "OpenedGameQ", Id.OpenedGameA to "OpenedGameA",
        Id.NetworkDataListeningQ to "NetworkDataListeningQ",
        Id.NetworkDataListeningA to "NetworkDataListeningA",
        Id.PingQ to "PingQ", Id.PingA to "PingA",
        Id.PlayingGameQ to "PlayingGameQ", Id.PlayingGameA to "PlayingGameA"
    )

    // login types
    const val LOGIN = 0
    const val GUEST = 1
    const val NEW_PLAYER = 2

    // variants
    const val TOWERS = 0
    const val RUSSIAN = 1

    // feed kinds
    const val GE_OPENED_GAMES = 0
    const val GE_ONLINE_PLAYERS = 3

    fun loginQ(name: String, type: Int = LOGIN, password: String? = null): ByteArray =
        build(Id.LoginQ) {
            u8(type); string(name); string(password); bool(false); u8(0)
        }

    fun openedGamesFeedQ(): ByteArray = build(Id.NetworkDataListeningQ) { u8(GE_OPENED_GAMES) }

    fun openedGameQ(aj: Int = RUSSIAN, minutes: Int = 10, inc: Int = 0, am: Int = 0, en: Int = 0, flag: Boolean = true): ByteArray =
        build(Id.OpenedGameQ) {
            u8(aj); u8(minutes); u8(inc); u8(am); u8(en); bool(flag)
        }

    fun connectGameQ(gameId: Long): ByteArray = build(Id.ConnectGameQ) { u32le(gameId); u8(1) }

    fun playingGameQ(move: String, moveTime: Int = 1000): ByteArray =
        build(Id.PlayingGameQ) {
            uintLE(moveTime.toLong() and 0xFFFFFF, 3)
            string(move)
            u8(0); u8(0xFF); u8(0xFF)
        }

    fun pingQ(): ByteArray = build(Id.PingQ) {}
}