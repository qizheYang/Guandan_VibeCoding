import 'package:flutter/foundation.dart';
import 'package:guandan_shared/guandan_shared.dart';

import '../services/ws_client.dart';

class RoomState extends ChangeNotifier {
  final WsClient ws;

  String? roomCode;
  int? mySeatIndex;
  String? myPlayerId;
  List<Player?> players = List.filled(4, null);
  List<bool> readyStatus = List.filled(4, false);
  String? errorMessage;
  bool gameStarted = false;

  // Game start data (passed to GameStateNotifier)
  List<GameCard>? initialHand;
  int? currentLevelValue;
  Map<int, int>? teamLevels;
  FlipCardInfo? flipCard;
  int? firstPlayer;
  List<PlayerPublicInfo>? playerInfos;

  RoomState(this.ws) {
    ws.messages.listen(_handleMessage);
  }

  void _handleMessage(ServerMsg msg) {
    switch (msg.type) {
      case 'roomCreated':
        roomCode = msg.payload['roomCode'] as String;
        mySeatIndex = msg.payload['seatIndex'] as int;
        myPlayerId = msg.payload['playerId'] as String;
        errorMessage = null;
        notifyListeners();

      case 'roomJoined':
        roomCode = msg.payload['roomCode'] as String;
        mySeatIndex = msg.payload['seatIndex'] as int;
        myPlayerId = msg.payload['playerId'] as String;
        final playerList = (msg.payload['players'] as List)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList();
        for (final p in playerList) {
          players[p.seatIndex] = p;
        }
        errorMessage = null;
        notifyListeners();

      case 'playerJoined':
        final p = Player.fromJson(msg.payload);
        players[p.seatIndex] = p;
        notifyListeners();

      case 'playerLeft':
        final seat = msg.payload['seatIndex'] as int;
        players[seat] = null;
        readyStatus[seat] = false;
        notifyListeners();

      case 'playerReady':
        final pid = msg.payload['playerId'] as String;
        for (int i = 0; i < 4; i++) {
          if (players[i]?.id == pid) {
            readyStatus[i] = true;
            break;
          }
        }
        notifyListeners();

      case 'gameStart':
        final handKeys = (msg.payload['yourHand'] as List).cast<String>();
        initialHand = handKeys.map(GameCard.fromKey).toList();
        currentLevelValue = msg.payload['currentLevel'] as int;
        teamLevels = (msg.payload['teamLevels'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int));
        flipCard = FlipCardInfo.fromJson(
            msg.payload['flipCard'] as Map<String, dynamic>);
        firstPlayer = msg.payload['firstPlayer'] as int;
        playerInfos = (msg.payload['playerInfos'] as List)
            .map((p) => PlayerPublicInfo.fromJson(p as Map<String, dynamic>))
            .toList();
        gameStarted = true;
        notifyListeners();

      case 'error':
        errorMessage = msg.payload['message'] as String;
        notifyListeners();
    }
  }

  void createRoom(String name) {
    ws.send(CreateRoomMsg(playerName: name).toMsg());
  }

  void joinRoom(String code, String name) {
    ws.send(JoinRoomMsg(roomCode: code, playerName: name).toMsg());
  }

  void setReady() {
    ws.send(const ReadyMsg().toMsg());
    if (mySeatIndex != null) {
      readyStatus[mySeatIndex!] = true;
      notifyListeners();
    }
  }

  void reset() {
    roomCode = null;
    mySeatIndex = null;
    myPlayerId = null;
    players = List.filled(4, null);
    readyStatus = List.filled(4, false);
    errorMessage = null;
    gameStarted = false;
    initialHand = null;
    notifyListeners();
  }
}
