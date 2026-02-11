import 'dart:convert';
import 'dart:io';

import 'package:guandan_shared/protocol/protocol.dart';
import 'room_manager.dart';

class ClientConnection {
  final WebSocket socket;
  final RoomManager roomManager;
  String? playerId;
  String? playerName;
  String? roomCode;
  int? seatIndex;

  ClientConnection(this.socket, this.roomManager);

  void listen() {
    socket.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final msg = ClientMsg.fromJson(json);
          _handle(msg);
        } catch (e) {
          send(errorMsg(message: 'Invalid message: $e'));
        }
      },
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );
  }

  void send(ServerMsg msg) {
    if (socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(msg.toJson()));
    }
  }

  void _handle(ClientMsg msg) {
    switch (msg.type) {
      case 'createRoom':
        roomManager.createRoom(this, msg.payload['playerName'] as String);
      case 'joinRoom':
        roomManager.joinRoom(
          this,
          msg.payload['roomCode'] as String,
          msg.payload['playerName'] as String,
        );
      case 'ready':
        roomManager.playerReady(this);
      case 'playCards':
        final keys = (msg.payload['cardKeys'] as List).cast<String>();
        roomManager.playCards(this, keys);
      case 'pass':
        roomManager.playerPass(this);
      case 'tributeGive':
        roomManager.tributeGive(this, msg.payload['cardKey'] as String);
      case 'tributeReturn':
        roomManager.tributeReturn(this, msg.payload['cardKey'] as String);
      default:
        send(errorMsg(message: 'Unknown message type: ${msg.type}'));
    }
  }

  void _handleDisconnect() {
    print('Player disconnected: $playerName ($playerId)');
    roomManager.playerDisconnected(this);
  }
}
