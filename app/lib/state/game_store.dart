import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine/board.dart';
import '../net/socket.dart';
import '../protocol/codec.dart';
import '../protocol/frames.dart';

enum LoginMode { login, register, guest }

class GameStore extends ChangeNotifier {
  final GameSocket socket;

  GameStore({String? url})
      : socket = GameSocket(url ??
            const String.fromEnvironment('SERVER_URL',
                defaultValue: 'wss://c.keestra.workers.dev')) {
    socket.frames.listen(_onFrame);
    socket.status.listen((s) {
      if (s == SocketStatus.disconnected) {
        connected = false;
        notifyListeners();
      } else if (s == SocketStatus.connected) {
        connected = true;
        notifyListeners();
      }
    });
  }

  bool connected = false;
  bool loggedIn = false;
  String? name;
  bool premium = false;
  String? status;

  List<Advert> adverts = [];
  Advert? myAdvert;
  List<PlayerRow> players = [];

  PlayingState? game;
  Draughts? board;
  String? myColor;
  bool myTurn = false;
  List<String> chat = [];
  final List<String> moveLog = [];
  bool _rewindPending = false;
  String? _pendingMove;
  Timer? _moveTimer;

  bool get isGuest => loggedIn && !premium && name != null && name!.startsWith('[');

  Future<void> connect() async {
    status = 'Connecting...';
    notifyListeners();
    await socket.connect();
  }

  void _onFrame(Frame f) {
    switch (f.id) {
      case ID.loginA:
        final n = parseLoginA(f);
        if (n != null) {
          name = n;
          loggedIn = true;
          status = null;
        }
        break;
      case ID.openedGamesN:
        final d = parseOpenedGamesN(f);
        if (d != null) {
          final byId = {for (final a in adverts) a.gameId: a};
          for (final id in d.removed) {
            byId.remove(id);
            if (myAdvert?.gameId == id) myAdvert = null;
          }
          for (final a in d.added) {
            byId[a.gameId] = a;
            if (name != null && a.owner == name) myAdvert = a;
          }
          adverts = byId.values.toList();
        }
        break;
      case ID.playersN:
        final d = parsePlayersN(f);
        if (d != null) {
          final byName = {for (final p in players) p.name: p};
          for (final n in d.removed) {
            byName.remove(n);
          }
          for (final p in d.added) {
            byName[p.name] = p;
          }
          players = byName.values.toList();
        }
        break;
      case ID.connectGameA:
        final st = parseConnectGameA(f);
        if (st != null) _startGame(st);
        break;
      case ID.stateN:
        // A full state push (used by the force-rewind after a skipped capture).
        final st = parseStateN(f);
        if (st != null) {
          if (game == null) {
            _startGame(st);
          } else {
            if (_rewindPending && moveLog.isNotEmpty) {
              moveLog.removeLast();
              _rewindPending = false;
            }
            game = st;
            _rebuildBoard();
          }
        }
        break;
      case ID.playingGameN:
        final u = parsePlayingGameN(f);
        if (u != null) {
          _moveTimer?.cancel();
          if (game == null) {
            _startGame(u.state);
          } else {
            game = u.state;
            if (u.move != null && u.move!.isNotEmpty && board != null) {
              _applyMoveText(board!, u.move!);
              moveLog.add(u.move!);
              myTurn = true;
            }
          }
        }
        break;
      case ID.playingGameA:
        final ge = parsePlayingGameA(f);
        if (ge == 0) {
          _moveTimer?.cancel();
          myTurn = true;
          status = 'Move not accepted';
        } else if (ge == 1) {
          _moveTimer?.cancel();
          if (_pendingMove != null) {
            moveLog.add(_pendingMove!);
            _pendingMove = null;
          }
        } else if (ge == 2) {
          _moveTimer?.cancel();
          status = 'Game over';
        }
        break;
      case ID.chatN:
        final text = parseChatN(f);
        if (text != null && text.isNotEmpty) {
          chat = [...chat, text];
          final lower = text.toLowerCase();
          if (lower.contains('skipped a capture') ||
              lower.contains('forced capture')) {
            _rewindPending = true;
          }
        }
        break;
    }
    notifyListeners();
  }

  void _startGame(PlayingState st) {
    game = st;
    myColor = st.white == name ? 'white' : 'black';
    moveLog.clear();
    board = Draughts(whiteToMove: true, huffing: true);
    myTurn = myColor == 'white';
    status = null;
  }

  void _rebuildBoard() {
    final b = Draughts(whiteToMove: true, huffing: true);
    for (final m in moveLog) {
      _applyMoveText(b, m);
    }
    board = b;
    myTurn = (moveLog.length % 2 == 0 && myColor == 'white') ||
        (moveLog.length % 2 == 1 && myColor == 'black');
  }

  void _applyMoveText(Draughts b, String text) {
    final parts = text.split(RegExp('[x-]'));
    final from = Square.parse(parts.first);
    if (from == null) return;
    final path = <Square>[];
    for (final p in parts.skip(1)) {
      final sq = Square.parse(p);
      if (sq != null) path.add(sq);
    }
    if (path.isEmpty) return;
    final captures = <Square>[];
    if (text.contains('x')) {
      var prev = from;
      for (final sq in path) {
        captures.add(Square((prev.x + sq.x) ~/ 2, (prev.y + sq.y) ~/ 2));
        prev = sq;
      }
    }
    b.apply(Move(from, path, captures));
  }

  void login(String name, String password, LoginMode mode) {
    final type = switch (mode) {
      LoginMode.login => LoginType.login,
      LoginMode.register => LoginType.newPlayer,
      LoginMode.guest => LoginType.guest,
    };
    socket.send(loginQ(name, loginType: type, password: password));
    status = 'Connecting...';
    notifyListeners();
  }

  void subscribeLobby() {
    socket.send(openedGamesFeedQ());
  }

  void subscribePlayers({int variant = Variant.russian}) {
    socket.send(networkDataListeningQ(ge: Feed.onlinePlayers, du: variant));
  }

  void createGame({int variant = Variant.towers, int minutes = 3, int increment = 0}) {
    socket.send(openedGameQ(
      aj: variant,
      minutes: minutes,
      increment: increment,
      am: ColorChoice.any,
    ));
  }

  void joinGame(int gameId) {
    socket.send(connectGameQ(gameId));
  }

  void sendMove(String text) {
    if (board == null) return;
    _pendingMove = text;
    socket.send(playingGameQ(text));
    myTurn = false;
    _moveTimer?.cancel();
    _moveTimer = Timer(const Duration(seconds: 5), () {
      if (game != null && !myTurn && _pendingMove != null) {
        _pendingMove = null;
        myTurn = true;
        status = 'Move not accepted - try again';
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void sendChat(String text) {
    if (text.trim().isEmpty) return;
    socket.send(chatQ(text));
  }

  void leaveGame() {
    game = null;
    board = null;
    myColor = null;
    myTurn = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    socket.dispose();
    super.dispose();
  }
}

