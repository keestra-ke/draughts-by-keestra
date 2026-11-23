package com.keestra.draughts

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import java.util.concurrent.TimeUnit

/** Thin OkHttp WebSocket wrapper with a 20 s protocol ping. */
class GameSocket(private val url: String) {
    private val client = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .build()
    private var ws: WebSocket? = null

    var onFrame: ((ByteArray) -> Unit)? = null
    var onClosed: (() -> Unit)? = null

    fun connect() {
        val req = Request.Builder().url(url).build()
        ws = client.newWebSocket(req, object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                onFrame?.invoke(bytes.toByteArray())
            }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                onClosed?.invoke()
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                onClosed?.invoke()
            }
        })
    }

    fun send(bytes: ByteArray) {
        ws?.send(ByteString.of(*bytes))
    }

    fun close() {
        ws?.close(1000, "bye")
        ws = null
    }
}