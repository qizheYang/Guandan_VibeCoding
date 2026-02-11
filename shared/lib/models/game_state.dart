import 'card.dart';

enum GamePhase { waiting, dealing, tribute, playing, roundEnd, gameEnd }

class PlayerPublicInfo {
  final String playerId;
  final String name;
  final int seatIndex;
  final int cardCount;
  final int? finishOrder;
  final bool passed;

  const PlayerPublicInfo({
    required this.playerId,
    required this.name,
    required this.seatIndex,
    required this.cardCount,
    this.finishOrder,
    this.passed = false,
  });

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'name': name,
    'seatIndex': seatIndex,
    'cardCount': cardCount,
    'finishOrder': finishOrder,
    'passed': passed,
  };

  factory PlayerPublicInfo.fromJson(Map<String, dynamic> j) =>
      PlayerPublicInfo(
        playerId: j['playerId'] as String,
        name: j['name'] as String,
        seatIndex: j['seatIndex'] as int,
        cardCount: j['cardCount'] as int,
        finishOrder: j['finishOrder'] as int?,
        passed: j['passed'] as bool? ?? false,
      );
}

class RoundResult {
  final List<int> finishOrder; // seat indices in finishing order
  final Map<int, int> teamLevelsBefore; // {0: level, 1: level}
  final Map<int, int> teamLevelsAfter;
  final int? winningTeam; // null if game continues

  const RoundResult({
    required this.finishOrder,
    required this.teamLevelsBefore,
    required this.teamLevelsAfter,
    this.winningTeam,
  });

  Map<String, dynamic> toJson() => {
    'finishOrder': finishOrder,
    'teamLevelsBefore': teamLevelsBefore.map((k, v) => MapEntry('$k', v)),
    'teamLevelsAfter': teamLevelsAfter.map((k, v) => MapEntry('$k', v)),
    'winningTeam': winningTeam,
  };

  factory RoundResult.fromJson(Map<String, dynamic> j) {
    final before = (j['teamLevelsBefore'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(int.parse(k), v as int));
    final after = (j['teamLevelsAfter'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(int.parse(k), v as int));
    return RoundResult(
      finishOrder: (j['finishOrder'] as List).cast<int>(),
      teamLevelsBefore: before,
      teamLevelsAfter: after,
      winningTeam: j['winningTeam'] as int?,
    );
  }
}

/// Info about the flipped card during dealing.
class FlipCardInfo {
  final GameCard card;
  final int position; // position in the deck (0-107)
  final int receiverSeat; // which seat gets this card

  const FlipCardInfo({
    required this.card,
    required this.position,
    required this.receiverSeat,
  });

  Map<String, dynamic> toJson() => {
    'card': card.toJson(),
    'position': position,
    'receiverSeat': receiverSeat,
  };

  factory FlipCardInfo.fromJson(Map<String, dynamic> j) => FlipCardInfo(
    card: GameCard.fromJson(j['card'] as Map<String, dynamic>),
    position: j['position'] as int,
    receiverSeat: j['receiverSeat'] as int,
  );
}
