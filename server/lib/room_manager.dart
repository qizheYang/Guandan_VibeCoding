import 'dart:math';

import 'package:guandan_shared/protocol/protocol.dart';

import 'client_connection.dart';
import 'game_session.dart';

class RoomManager {
  final Map<String, GameSession> _rooms = {};
  final _rng = Random();

  String _generateCode() {
    String code;
    do {
      code = (1000 + _rng.nextInt(9000)).toString();
    } while (_rooms.containsKey(code));
    return code;
  }

  void createRoom(ClientConnection conn, String playerName) {
    final code = _generateCode();
    final session = GameSession(code);
    _rooms[code] = session;
    session.addPlayer(conn, playerName);
    print('Room $code created by $playerName');
  }

  void joinRoom(ClientConnection conn, String code, String playerName) {
    final session = _rooms[code];
    if (session == null) {
      conn.send(errorMsg(message: 'Room $code not found'));
      return;
    }
    session.addPlayer(conn, playerName);
    print('$playerName joined room $code');
  }

  void playerReady(ClientConnection conn) {
    _getSession(conn)?.playerReady(conn);
  }

  void playCards(ClientConnection conn, List<String> cardKeys) {
    _getSession(conn)?.playCards(conn, cardKeys);
  }

  void playerPass(ClientConnection conn) {
    _getSession(conn)?.playerPass(conn);
  }

  void tributeGive(ClientConnection conn, String cardKey) {
    _getSession(conn)?.tributeGive(conn, cardKey);
  }

  void tributeReturn(ClientConnection conn, String cardKey) {
    _getSession(conn)?.tributeReturn(conn, cardKey);
  }

  void playerDisconnected(ClientConnection conn) {
    final session = _getSession(conn);
    if (session != null) {
      session.removePlayer(conn);
      if (session.isEmpty) {
        _rooms.remove(session.roomCode);
        print('Room ${session.roomCode} removed (empty)');
      }
    }
  }

  GameSession? _getSession(ClientConnection conn) {
    if (conn.roomCode == null) return null;
    return _rooms[conn.roomCode];
  }
}
