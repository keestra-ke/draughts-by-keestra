import 'dart:convert';
import 'dart:typed_data';

/// Binary protocol primitives for the Checkersland/Keestra wire format.
///
/// Every WebSocket binary message is one frame:
///   [0x39 magic] [1-byte message id] [payload]
/// All integers are little-endian; strings are u16 length + UTF-8 bytes
/// (0xFFFF = null); enums are one byte (0xFF = null).

const int magic = 0x39;

class Reader {
  final ByteData _data;
  int pos = 0;

  Reader(Uint8List bytes)
      : _data = ByteData.view(
            bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

  int get remaining => _data.lengthInBytes - pos;

  int u8() {
    final v = _data.getUint8(pos);
    pos += 1;
    return v;
  }

  int u16le() {
    final v = _data.getUint16(pos, Endian.little);
    pos += 2;
    return v;
  }

  int u32le() {
    final v = _data.getUint32(pos, Endian.little);
    pos += 4;
    return v;
  }

  int uintLE(int n) {
    var v = 0;
    for (var i = 0; i < n; i++) {
      v |= u8() << (8 * i);
    }
    return v >>> 0;
  }

  Uint8List bytes(int n) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      out[i] = u8();
    }
    return out;
  }

  String? string() {
    final len = u16le();
    if (len == 0xFFFF) return null;
    final raw = bytes(len);
    try {
      return utf8.decode(raw);
    } catch (_) {
      return String.fromCharCodes(raw);
    }
  }

  bool readBool() => u8() != 0;

  int? enumOrNull() {
    final v = u8();
    return v == 0xFF ? null : v;
  }
}

class Writer {
  final BytesBuilder _b = BytesBuilder(copy: false);
  int length = 0;

  void u8(int v) {
    _b.add(Uint8List.fromList([v & 0xFF]));
    length += 1;
  }

  void u16le(int v) {
    _b.add(Uint8List.fromList([v & 0xFF, (v >> 8) & 0xFF]));
    length += 2;
  }

  void u32le(int v) {
    _b.add(Uint8List.fromList([
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]));
    length += 4;
  }

  void uintLE(int v, int n) {
    for (var i = 0; i < n; i++) {
      _b.add(Uint8List.fromList([(v >> (8 * i)) & 0xFF]));
    }
    length += n;
  }

  void bytes(Uint8List data) {
    _b.add(data);
    length += data.length;
  }

  void string(String? s) {
    if (s == null || s.isEmpty) {
      u16le(0xFFFF);
      return;
    }
    final raw = Uint8List.fromList(utf8.encode(s));
    u16le(raw.length);
    _b.add(raw);
    length += raw.length;
  }

  void writeBool(bool v) => u8(v ? 1 : 0);

  void enumOrNull(int? v) => u8(v ?? 0xFF);

  Uint8List toBytes() => _b.toBytes();
}

class Frame {
  final int magicByte;
  final int id;
  final Reader reader;
  final Uint8List bytes;

  Frame._(this.magicByte, this.id, this.reader, this.bytes);

  String get name => frameNames[id] ?? 'id$id';

  static Frame? decode(Uint8List raw) {
    if (raw.length < 2) return null;
    final r = Reader(raw);
    final m = r.u8();
    if (m != magic) return null;
    final id = r.u8();
    return Frame._(m, id, r, raw);
  }
}

/// Build a binary frame from a payload writer.
Uint8List buildFrame(int id, void Function(Writer w) write) {
  final w = Writer();
  write(w);
  final out = Uint8List(2 + w.length);
  out[0] = magic;
  out[1] = id;
  out.setRange(2, out.length, w.toBytes());
  return out;
}

// Message ids (see PROTOCOL.md).
class ID {
  static const chatQ = 0;
  static const chatN = 1;
  static const stateN = 2;
  static const playersN = 3;
  static const openedGamesN = 4;
  static const playingGameN = 5;
  static const playingGamesListN = 6;
  static const playingGameLN = 7;
  static const chatEnabledQ = 8;
  static const chatEnabledA = 9;
  static const connectGameQ = 14;
  static const connectGameA = 15;
  static const drawQ = 16;
  static const drawA = 17;
  static const leaderboardQ = 20;
  static const leaderboardA = 21;
  static const loginQ = 22;
  static const loginA = 23;
  static const openedGameQ = 24;
  static const openedGameA = 25;
  static const networkDataListeningQ = 26;
  static const networkDataListeningA = 27;
  static const pingQ = 28;
  static const pingA = 29;
  static const playingGameQ = 30;
  static const playingGameA = 31;
  static const profileQ = 32;
  static const profileA = 33;
}

const Map<int, String> frameNames = {
  ID.chatQ: 'ChatQ',
  ID.chatN: 'ChatN',
  ID.stateN: 'StateN',
  ID.playersN: 'PlayersN',
  ID.openedGamesN: 'OpenedGamesN',
  ID.playingGameN: 'PlayingGameN',
  ID.playingGamesListN: 'PlayingGamesListN',
  ID.playingGameLN: 'PlayingGameLN',
  ID.chatEnabledQ: 'ChatEnabledQ',
  ID.chatEnabledA: 'ChatEnabledA',
  ID.connectGameQ: 'ConnectGameQ',
  ID.connectGameA: 'ConnectGameA',
  ID.drawQ: 'DrawQ',
  ID.drawA: 'DrawA',
  ID.leaderboardQ: 'LeaderboardQ',
  ID.leaderboardA: 'LeaderboardA',
  ID.loginQ: 'LoginQ',
  ID.loginA: 'LoginA',
  ID.openedGameQ: 'OpenedGameQ',
  ID.openedGameA: 'OpenedGameA',
  ID.networkDataListeningQ: 'NetworkDataListeningQ',
  ID.networkDataListeningA: 'NetworkDataListeningA',
  ID.pingQ: 'PingQ',
  ID.pingA: 'PingA',
  ID.playingGameQ: 'PlayingGameQ',
  ID.playingGameA: 'PlayingGameA',
  ID.profileQ: 'ProfileQ',
  ID.profileA: 'ProfileA',
};

// Login types (FU).
class LoginType {
  static const login = 0;
  static const guest = 1;
  static const newPlayer = 2;
}

// Game variants (AJ) — index into the app's variant list.
class Variant {
  static const towers = 0; // Kenyan Nairobi
  static const russian = 1;
  static const giveaway = 2;
  static const checkers = 3;
  static const laska = 4;
  static const international = 5;
}

// Any / White / Black (renamed to avoid clashing with Flutter's Color).
class ColorChoice {
  static const any = 0;
  static const white = 1;
  static const black = 2;
}

// Feed kinds (GE).
class Feed {
  static const openedGames = 0;
  static const playingGame = 1;
  static const playingGamesList = 2;
  static const onlinePlayers = 3;
}