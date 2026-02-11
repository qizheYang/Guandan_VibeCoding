import '../models/card.dart';
import '../models/card_combo.dart';
import '../models/game_state.dart';
import '../models/player.dart';

class ServerMsg {
  final String type;
  final Map<String, dynamic> payload;

  const ServerMsg({required this.type, required this.payload});

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};

  factory ServerMsg.fromJson(Map<String, dynamic> j) => ServerMsg(
    type: j['type'] as String,
    payload: j['payload'] as Map<String, dynamic>? ?? {},
  );
}

// ── Helper constructors for server-to-client messages ──

ServerMsg roomCreatedMsg({
  required String roomCode,
  required int seatIndex,
  required String playerId,
}) =>
    ServerMsg(type: 'roomCreated', payload: {
      'roomCode': roomCode,
      'seatIndex': seatIndex,
      'playerId': playerId,
    });

ServerMsg roomJoinedMsg({
  required String roomCode,
  required int seatIndex,
  required String playerId,
  required List<Player> players,
}) =>
    ServerMsg(type: 'roomJoined', payload: {
      'roomCode': roomCode,
      'seatIndex': seatIndex,
      'playerId': playerId,
      'players': players.map((p) => p.toJson()).toList(),
    });

ServerMsg playerJoinedMsg({required Player player}) =>
    ServerMsg(type: 'playerJoined', payload: player.toJson());

ServerMsg playerLeftMsg({required String playerId, required int seatIndex}) =>
    ServerMsg(type: 'playerLeft', payload: {
      'playerId': playerId,
      'seatIndex': seatIndex,
    });

ServerMsg playerReadyMsg({required String playerId}) =>
    ServerMsg(type: 'playerReady', payload: {'playerId': playerId});

ServerMsg gameStartMsg({
  required List<GameCard> yourHand,
  required int currentLevelValue,
  required Map<int, int> teamLevels,
  required FlipCardInfo flipCard,
  required int firstPlayer,
  required List<PlayerPublicInfo> playerInfos,
}) =>
    ServerMsg(type: 'gameStart', payload: {
      'yourHand': yourHand.map((c) => c.key).toList(),
      'currentLevel': currentLevelValue,
      'teamLevels': teamLevels.map((k, v) => MapEntry('$k', v)),
      'flipCard': flipCard.toJson(),
      'firstPlayer': firstPlayer,
      'playerInfos':
          playerInfos.map((p) => p.toJson()).toList(),
    });

ServerMsg yourTurnMsg({
  required CardCombo? currentTrick,
  required int consecutivePasses,
}) =>
    ServerMsg(type: 'yourTurn', payload: {
      'currentTrick': currentTrick?.toJson(),
      'consecutivePasses': consecutivePasses,
    });

ServerMsg cardsPlayedMsg({
  required String playerId,
  required int seatIndex,
  required List<GameCard> cards,
  required String comboType,
  required int cardCount,
}) =>
    ServerMsg(type: 'cardsPlayed', payload: {
      'playerId': playerId,
      'seatIndex': seatIndex,
      'cards': cards.map((c) => c.key).toList(),
      'comboType': comboType,
      'cardCount': cardCount,
    });

ServerMsg playerPassedMsg({
  required String playerId,
  required int seatIndex,
}) =>
    ServerMsg(type: 'playerPassed', payload: {
      'playerId': playerId,
      'seatIndex': seatIndex,
    });

ServerMsg trickWonMsg({
  required String winnerId,
  required int winnerSeat,
}) =>
    ServerMsg(type: 'trickWon', payload: {
      'winnerId': winnerId,
      'winnerSeat': winnerSeat,
    });

ServerMsg playerFinishedMsg({
  required String playerId,
  required int seatIndex,
  required int place,
}) =>
    ServerMsg(type: 'playerFinished', payload: {
      'playerId': playerId,
      'seatIndex': seatIndex,
      'place': place,
    });

ServerMsg roundEndMsg({required RoundResult result}) =>
    ServerMsg(type: 'roundEnd', payload: result.toJson());

ServerMsg tributePhaseMsg({
  required List<Map<String, dynamic>> tributeRequests,
}) =>
    ServerMsg(type: 'tributePhase', payload: {
      'tributeRequests': tributeRequests,
    });

ServerMsg gameOverMsg({required int winningTeam}) =>
    ServerMsg(type: 'gameOver', payload: {'winningTeam': winningTeam});

ServerMsg seatsAssignedMsg({required List<Player> players}) =>
    ServerMsg(type: 'seatsAssigned', payload: {
      'players': players.map((p) => p.toJson()).toList(),
    });

ServerMsg errorMsg({required String message}) =>
    ServerMsg(type: 'error', payload: {'message': message});
