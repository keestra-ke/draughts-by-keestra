import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../protocol/codec.dart';

/// WebSocket transport with reconnect, heartbeat and frame decoding.
class GameSocket {
  final String url;
  WebSocketChannel? _channel;
  final _frames = StreamController<Frame>.broadcast();
  final _status = StreamController<SocketStatus>.broadcast();
  Timer? _heartbeat;
  Timer? _reconnect;
  int _retry = 0;
  bool _closed = false;

  GameSocket(this.url);

  Stream<Frame> get frames => _frames.stream;
  Stream<SocketStatus> get status => _status.stream;
  bool get connected => _channel != null;

  Future<void> connect() async {
    _closed = false;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      _retry = 0;
      _status.add(SocketStatus.connected);
      channel.stream.listen(
        (data) {
          final bytes = data is Uint8List ? data : Uint8List.fromList(data as List<int>);
          final frame = Frame.decode(bytes);
          if (frame != null) _frames.add(frame);
        },
        onError: (e) => _handleDrop(),
        onDone: () => _handleDrop(),
        cancelOnError: true,
      );
      _startHeartbeat();
    } catch (e) {
      _status.add(SocketStatus.error);
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      send(playingPing());
    });
  }

  void send(Uint8List frame) {
    try {
      _channel?.sink.add(frame);
    } catch (_) {}
  }

  void _handleDrop() {
    _heartbeat?.cancel();
    if (_closed) return;
    _status.add(SocketStatus.disconnected);
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnect?.cancel();
    _retry++;
    final delay = Duration(milliseconds: (500 * (1 << (_retry.clamp(0, 5) - 1)).clamp(1, 16000)));
    _reconnect = Timer(delay, () {
      if (!_closed) connect();
    });
  }

  Future<void> close() async {
    _closed = true;
    _heartbeat?.cancel();
    _reconnect?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await close();
    await _frames.close();
    await _status.close();
  }
}

enum SocketStatus { connected, disconnected, error }

Uint8List playingPing() => buildFrame(ID.pingQ, (w) {});