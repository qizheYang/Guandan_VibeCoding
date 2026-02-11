import 'package:flutter/foundation.dart';
import 'package:guandan_shared/guandan_shared.dart';

import '../services/ws_client.dart';

class GameStateNotifier extends ChangeNotifier {
  final WsClient ws;
  final int mySeatIndex;
  final String myPlayerId;

  List<GameCard> myHand = [];
  Rank? currentLevel;
  Map<int, int> teamLevels = {};
  bool isMyTurn = false;
  CardCombo? currentTrick;
  int consecutivePasses = 0;
  Set<int> selectedIndices = {}; // indices in myHand
  String? errorMessage;
  RoundResult? roundResult;
  GamePhase phase = GamePhase.playing;
  FlipCardInfo? flipCard;

  // Per-seat state
  Map<int, int> cardCounts = {};
  Map<int, int?> finishPlaces = {};
  Map<int, List<GameCard>?> lastPlayedCards = {};
  Map<int, bool> passedThisTrick = {};
  Map<int, String> playerNames = {};
  int? trickWinnerSeat;
  bool gameOver = false;
  int? winningTeam;

  GameStateNotifier({
    required this.ws,
    required this.mySeatIndex,
    required this.myPlayerId,
  }) {
    ws.messages.listen(_handleMessage);
  }

  void initFromRoomState({
    required List<GameCard> hand,
    required int levelValue,
    required Map<int, int> levels,
    required FlipCardInfo flip,
    required int firstPlayer,
    required List<PlayerPublicInfo> infos,
  }) {
    myHand = hand;
    currentLevel = Rank.fromValue(levelValue);
    teamLevels = levels;
    flipCard = flip;
    isMyTurn = firstPlayer == mySeatIndex;
    phase = GamePhase.playing;
    selectedIndices = {};
    roundResult = null;
    gameOver = false;
    winningTeam = null;
    trickWinnerSeat = null;
    currentTrick = null;
    consecutivePasses = 0;

    for (final info in infos) {
      cardCounts[info.seatIndex] = info.cardCount;
      finishPlaces[info.seatIndex] = null;
      lastPlayedCards[info.seatIndex] = null;
      passedThisTrick[info.seatIndex] = false;
      playerNames[info.seatIndex] = info.name;
    }

    _sortHand();
    notifyListeners();
  }

  void _handleMessage(ServerMsg msg) {
    switch (msg.type) {
      case 'yourTurn':
        isMyTurn = true;
        if (msg.payload['currentTrick'] != null) {
          currentTrick = CardCombo.fromJson(
              msg.payload['currentTrick'] as Map<String, dynamic>);
        } else {
          currentTrick = null;
        }
        consecutivePasses = msg.payload['consecutivePasses'] as int;
        errorMessage = null;
        notifyListeners();

      case 'cardsPlayed':
        final seat = msg.payload['seatIndex'] as int;
        final cardKeys = (msg.payload['cards'] as List).cast<String>();
        final cards = cardKeys.map(GameCard.fromKey).toList();
        final count = msg.payload['cardCount'] as int;

        lastPlayedCards[seat] = cards;
        cardCounts[seat] = count;
        passedThisTrick = {0: false, 1: false, 2: false, 3: false};
        trickWinnerSeat = null;

        // If it was me, remove cards from hand
        if (seat == mySeatIndex) {
          for (final card in cards) {
            myHand.remove(card);
          }
          selectedIndices = {};
          isMyTurn = false;
        }
        notifyListeners();

      case 'playerPassed':
        final seat = msg.payload['seatIndex'] as int;
        passedThisTrick[seat] = true;
        lastPlayedCards[seat] = null;
        if (seat == mySeatIndex) {
          isMyTurn = false;
        }
        notifyListeners();

      case 'trickWon':
        final winnerSeat = msg.payload['winnerSeat'] as int;
        trickWinnerSeat = winnerSeat;
        currentTrick = null;
        consecutivePasses = 0;
        // Clear all last plays for new trick
        for (int i = 0; i < 4; i++) {
          lastPlayedCards[i] = null;
          passedThisTrick[i] = false;
        }
        notifyListeners();

      case 'playerFinished':
        final seat = msg.payload['seatIndex'] as int;
        final place = msg.payload['place'] as int;
        finishPlaces[seat] = place;
        notifyListeners();

      case 'roundEnd':
        roundResult = RoundResult.fromJson(msg.payload);
        phase = GamePhase.roundEnd;
        notifyListeners();

      case 'gameOver':
        gameOver = true;
        winningTeam = msg.payload['winningTeam'] as int;
        phase = GamePhase.gameEnd;
        notifyListeners();

      case 'error':
        errorMessage = msg.payload['message'] as String;
        notifyListeners();
    }
  }

  // ── User Actions ──

  void toggleCardSelection(int index) {
    if (selectedIndices.contains(index)) {
      selectedIndices.remove(index);
    } else {
      selectedIndices.add(index);
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedIndices = {};
    notifyListeners();
  }

  List<GameCard> get selectedCards =>
      selectedIndices.map((i) => myHand[i]).toList();

  /// Try to play selected cards. Returns error message or null on success.
  String? playSelected() {
    if (!isMyTurn || selectedIndices.isEmpty) return 'Not your turn or no cards selected';

    // Client-side pre-validation
    final cards = selectedCards;
    if (currentLevel == null) return 'Game not started';

    final combo = ComboDetector.detect(cards, currentLevel!);
    if (combo == null) return 'Invalid combination';

    if (currentTrick != null && !ComboDetector.canBeat(combo, currentTrick)) {
      return 'Does not beat current trick';
    }

    // Send to server (server does authoritative validation)
    ws.send(PlayCardsMsg(cardKeys: cards.map((c) => c.key).toList()).toMsg());
    return null;
  }

  void pass() {
    if (!isMyTurn) return;
    ws.send(const PassMsg().toMsg());
  }

  bool get canPass => isMyTurn && currentTrick != null;
  bool get canPlay => isMyTurn && selectedIndices.isNotEmpty;

  int get myTeam => mySeatIndex % 2;

  /// Get seat index relative to my position.
  int relativeSeat(int offset) => (mySeatIndex + offset) % 4;
  int get partnerSeat => relativeSeat(2);
  int get leftOpponentSeat => relativeSeat(3);
  int get rightOpponentSeat => relativeSeat(1);

  void _sortHand() {
    if (currentLevel == null) return;
    final level = currentLevel!;
    myHand.sort((a, b) {
      // Wilds go to the right
      final aWild = a.isWild(level);
      final bWild = b.isWild(level);
      if (aWild && !bWild) return 1;
      if (!aWild && bWild) return -1;

      final ra = a.effectiveRank(level);
      final rb = b.effectiveRank(level);
      if (ra != rb) return ra.compareTo(rb);

      final sa = a.suit?.index ?? 99;
      final sb = b.suit?.index ?? 99;
      return sa.compareTo(sb);
    });
  }
}
