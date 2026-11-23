import 'dart:typed_data';
import 'codec.dart';

/// One open-game advert as the lobby shows it.
class Advert {
  final int gameId;
  final int variant;
  final String owner;
  final int rating;
  final int minutes;
  final int increment;
  final int color; // AM
  final int en; // EN
  final String? opponent;

  Advert({
    required this.gameId,
    required this.variant,
    required this.owner,
    required this.rating,
    required this.minutes,
    required this.increment,
    required this.color,
    required this.en,
    this.opponent,
  });
}

/// A player row in the online-players list.
class PlayerRow {
  final String name;
  final int rating;
  PlayerRow(this.name, this.rating);
}

/// The game state the server sends with ConnectGameA / PlayingGameN.
class PlayingState {
  final int flags; // gD
  final int variant;
  final int minutes;
  final int increment;
  final String white;
  final String black;
  final int historyLength;
  final Uint8List histBytes;

  PlayingState({
    required this.flags,
    required this.variant,
    required this.minutes,
    required this.increment,
    required this.white,
    required this.black,
    required this.historyLength,
    required this.histBytes,
  });
}

// ---------- outgoing ----------

Uint8List loginQ(String name,
    {int loginType = LoginType.login,
    String? password,
    bool device = false,
    Map<int, String> info = const {}}) {
  return buildFrame(ID.loginQ, (w) {
    w.u8(loginType);
    w.string(name);
    w.string(password);
    w.writeBool(device);
    final keys = info.keys.toList()..sort();
    w.u8(keys.length);
    for (final k in keys) {
      w.u8(k);
      w.string(info[k]);
    }
  });
}

Uint8List networkDataListeningQ({int? ge, int? du, int? gameId}) {
  return buildFrame(ID.networkDataListeningQ, (w) {
    if (ge == null) {
      w.u8(0xFF);
      return;
    }
    w.u8(ge);
    if (ge == Feed.playingGame) {
      w.u32le(gameId ?? 0);
    } else if (ge != Feed.openedGames) {
      w.u8(du ?? 0xFF);
    }
  });
}

Uint8List openedGamesFeedQ() => networkDataListeningQ(ge: Feed.openedGames);

Uint8List openedGameQ({
  int aj = Variant.russian,
  int minutes = 10,
  int increment = 0,
  int am = ColorChoice.any,
  int en = 0,
  bool flag = true,
  String? opponent,
  bool cancel = false,
}) {
  return buildFrame(ID.openedGameQ, (w) {
    if (cancel) {
      w.u8(0xFF);
      return;
    }
    w.u8(aj);
    w.u8(minutes);
    w.u8(increment);
    w.u8(am);
    w.u8(opponent != null ? 1 : en);
    w.writeBool(flag);
    if (opponent != null) w.string(opponent);
  });
}

Uint8List connectGameQ(int gameId, [int b = 1]) {
  return buildFrame(ID.connectGameQ, (w) {
    w.u32le(gameId);
    w.u8(b);
  });
}

Uint8List playingGameQ(String move, {int moveTime = 1000, int ai = 0, int? u, int? ag}) {
  return buildFrame(ID.playingGameQ, (w) {
    w.uintLE(moveTime & 0xFFFFFF, 3);
    w.string(move);
    w.u8(ai);
    w.u8(u ?? 0xFF);
    w.u8(ag ?? 0xFF);
  });
}

Uint8List pingQ() => buildFrame(ID.pingQ, (w) {});
Uint8List chatQ(String text) => buildFrame(ID.chatQ, (w) => w.string(text));
Uint8List leaderboardQ() => buildFrame(ID.leaderboardQ, (w) {});

// ---------- incoming ----------

String? parseLoginA(Frame f) {
  final r = f.reader;
  r.u16le(); // server time
  return r.string();
}

class FeedState {
  final int ge;
  final int? du;
  final int? gameId;
  FeedState(this.ge, {this.du, this.gameId});
}

FeedState? parseNetworkDataListeningA(Frame f) {
  final r = f.reader;
  r.u16le();
  final result = r.u8();
  if (result != 0) return null;
  final gf = r.u8();
  if (gf != 1 || r.remaining <= 0) return null;
  final ge = r.u8();
  if (ge == Feed.playingGame) {
    if (r.remaining < 4) return FeedState(ge);
    return FeedState(ge, gameId: r.u32le());
  }
  if (ge != Feed.openedGames && r.remaining > 0) {
    return FeedState(ge, du: r.u8());
  }
  return FeedState(ge);
}

class OpenedGamesDelta {
  final List<Advert> added;
  final List<int> removed;
  OpenedGamesDelta(this.added, this.removed);
}

OpenedGamesDelta? parseOpenedGamesN(Frame f) {
  final r = f.reader;
  if (r.remaining < 2) return null;
  final n = r.u16le();
  final added = <Advert>[];
  for (var i = 0; i < n; i++) {
    final flags = r.u8();
    final gameId = r.u32le();
    final variant = r.u8();
    final owner = r.string() ?? '';
    final rating = r.u16le();
    final minutes = r.u8();
    final increment = r.u8();
    if (flags & 1 != 0) r.u8();
    if (flags & 2 != 0) {
      final en = r.u8();
      if (en == 1) r.string(); // selected-player opponent name
    }
    added.add(Advert(
      gameId: gameId,
      variant: variant,
      owner: owner,
      rating: rating,
      minutes: minutes,
      increment: increment,
      color: ColorChoice.any,
      en: 0,
    ));
  }
  final removed = <int>[];
  if (r.remaining >= 2) {
    final g = r.u16le();
    for (var i = 0; i < g && r.remaining >= 4; i++) {
      removed.add(r.u32le());
    }
  }
  return OpenedGamesDelta(added, removed);
}

class PlayersDelta {
  final List<PlayerRow> added;
  final List<String> removed;
  PlayersDelta(this.added, this.removed);
}

PlayersDelta? parsePlayersN(Frame f) {
  final r = f.reader;
  if (r.remaining < 2) return null;
  final n = r.u16le();
  final added = <PlayerRow>[];
  for (var i = 0; i < n; i++) {
    final name = r.string() ?? '';
    final rating = r.u16le();
    added.add(PlayerRow(name, rating));
  }
  final removed = <String>[];
  if (r.remaining >= 2) {
    final g = r.u16le();
    for (var i = 0; i < g; i++) {
      final name = r.string();
      if (name != null) removed.add(name);
    }
  }
  return PlayersDelta(added, removed);
}

PlayingState? parsePlayingState(Reader r) {
  final gD = r.u8();
  final variant = r.u8();
  final minutes = r.u8();
  final increment = r.u8();
  final white = r.string() ?? '';
  final black = r.string() ?? '';
  r.uintLE(3); // white clock
  r.uintLE(3); // black clock
  if (gD & 0x04 != 0) r.u8(); // draw state
  final histLen = r.u16le();
  final hist = histLen > 0 && r.remaining >= histLen ? r.bytes(histLen) : Uint8List(0);
  return PlayingState(
    flags: gD,
    variant: variant,
    minutes: minutes,
    increment: increment,
    white: white,
    black: black,
    historyLength: histLen,
    histBytes: hist,
  );
}

PlayingState? parseConnectGameA(Frame f) {
  final r = f.reader;
  r.u16le(); // server time
  r.u8(); // result
  final gf = r.u8();
  if (gf != 4) return null;
  return parsePlayingState(r);
}

class PlayingGameUpdate {
  final PlayingState state;
  final String? move;
  PlayingGameUpdate(this.state, this.move);
}

PlayingGameUpdate? parsePlayingGameN(Frame f) {
  final r = f.reader;
  final gf = r.u8();
  if (gf != 4) return null;
  final state = parsePlayingState(r);
  if (state == null) return null;
  String? move;
  if (r.remaining >= 2) move = r.string();
  return PlayingGameUpdate(state, move);
}

/// 0 = OUTDATED, 1 = MOVE_SENT, 2 = GAME_OVER
int? parsePlayingGameA(Frame f) {
  final r = f.reader;
  r.u16le();
  return r.u8();
}

String? parseChatN(Frame f) => f.reader.string();

/// StateN can carry a feed, an advert, or a full playing state (gf = 4).
PlayingState? parseStateN(Frame f) {
  final r = f.reader;
  final gf = r.u8();
  if (gf != 4) return null;
  return parsePlayingState(r);
}

