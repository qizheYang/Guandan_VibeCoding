import 'dart:math';

import '../models/card.dart';
import '../models/card_combo.dart';
import '../models/combo_detector.dart';
import '../models/game_state.dart';

class GameEngine {
  // ── State ──
  late List<List<GameCard>> hands; // hands[seatIndex]
  late Rank currentLevel;
  late Map<int, Rank> teamLevels; // {teamId: rank}
  late int currentPlayer;
  CardCombo? currentTrick;
  late int trickLeader;
  int consecutivePasses = 0;
  List<int> finishOrder = [];
  GamePhase phase = GamePhase.waiting;
  FlipCardInfo? flipCard;

  // Track last play per seat for display
  Map<int, CardCombo?> lastPlay = {};
  Map<int, bool> passedThisTrick = {};

  final Random _rng;

  GameEngine({
    Map<int, Rank>? teamLevels,
    Random? rng,
  })  : _rng = rng ?? Random(),
        teamLevels = teamLevels ?? {0: Rank.two, 1: Rank.two};

  /// The current level for play (derived from the team that's "active" this round).
  /// In Guan Dan, both teams play at the higher of their two levels? No -
  /// actually each team has its own level, and the current round's level
  /// is determined by the team of the player who goes first.
  /// For simplicity: use the level of the team whose turn it is to lead first.
  Rank get activeLevel => currentLevel;

  // ── Deal ──

  /// Shuffle and deal 27 cards each. Simulate flipping a random card to
  /// determine who goes first.
  void deal({int? firstPlayerOverride}) {
    final deck = buildFullDeck();
    deck.shuffle(_rng);

    // Pick a random card position to "flip"
    final flipPos = _rng.nextInt(108);
    final flippedCard = deck[flipPos];

    // Deal clockwise: card i goes to seat i % 4
    hands = List.generate(4, (_) => <GameCard>[]);
    for (int i = 0; i < 108; i++) {
      hands[i % 4].add(deck[i]);
    }

    // The player who received the flipped card goes first
    final receiverSeat = flipPos % 4;
    flipCard = FlipCardInfo(
      card: flippedCard,
      position: flipPos,
      receiverSeat: receiverSeat,
    );

    currentPlayer = firstPlayerOverride ?? receiverSeat;

    // Determine current level: use the first player's team level
    final firstTeam = currentPlayer % 2;
    currentLevel = teamLevels[firstTeam]!;

    // Sort each hand
    for (final hand in hands) {
      hand.sort((a, b) => _compareCards(a, b));
    }

    // Reset round state
    currentTrick = null;
    consecutivePasses = 0;
    finishOrder = [];
    lastPlay = {0: null, 1: null, 2: null, 3: null};
    passedThisTrick = {0: false, 1: false, 2: false, 3: false};
    phase = GamePhase.playing;
  }

  // ── Play Cards ──

  /// Validate and play cards from [seatIndex]. Returns the combo on success.
  /// Throws on invalid play.
  CardCombo playCards(int seatIndex, List<GameCard> cards) {
    _validateTurn(seatIndex);
    if (phase != GamePhase.playing) {
      throw StateError('Game is not in playing phase');
    }
    if (cards.isEmpty) {
      throw ArgumentError('Must play at least one card');
    }

    // 1. Verify player holds these cards
    _validateOwnership(seatIndex, cards);

    // 2. Detect combination
    final combo = ComboDetector.detect(cards, currentLevel);
    if (combo == null) {
      throw ArgumentError('Cards do not form a valid combination');
    }

    // 3. If there's a current trick, verify this beats it
    if (currentTrick != null && !ComboDetector.canBeat(combo, currentTrick)) {
      throw ArgumentError('Play does not beat the current trick');
    }

    // 4. Remove cards from hand
    _removeCards(seatIndex, cards);

    // 5. Update state
    currentTrick = combo;
    trickLeader = seatIndex;
    consecutivePasses = 0;
    lastPlay[seatIndex] = combo;
    passedThisTrick = {0: false, 1: false, 2: false, 3: false};

    // 6. Check if player finished
    if (hands[seatIndex].isEmpty) {
      finishOrder.add(seatIndex);
      if (finishOrder.length >= 3) {
        // Last player auto-finishes
        for (int i = 0; i < 4; i++) {
          if (!finishOrder.contains(i)) {
            finishOrder.add(i);
            break;
          }
        }
        phase = GamePhase.roundEnd;
        return combo;
      }
    }

    _advanceToNextPlayer();
    return combo;
  }

  // ── Pass ──

  void pass(int seatIndex) {
    _validateTurn(seatIndex);
    if (currentTrick == null) {
      throw StateError('Cannot pass when leading a new trick');
    }

    passedThisTrick[seatIndex] = true;
    consecutivePasses++;
    lastPlay[seatIndex] = null;

    // Check if trick is won (all other active players passed)
    final activePlayers = _countActivePlayers();
    final passesNeeded = activePlayers - 1;

    // Also handle case where trick leader has finished
    final leaderFinished = hands[trickLeader].isEmpty;

    if (consecutivePasses >= passesNeeded ||
        (leaderFinished && consecutivePasses >= activePlayers)) {
      // Trick won by trickLeader
      _startNewTrick();
    } else {
      _advanceToNextPlayer();
    }
  }

  // ── Round Result ──

  RoundResult calculateRoundResult() {
    final before = Map<int, int>.from(
        teamLevels.map((k, v) => MapEntry(k, v.value)));

    // Determine advancement
    // finishOrder[0] = 1st place seat, finishOrder[1] = 2nd place seat
    final firstSeat = finishOrder[0];
    final secondSeat = finishOrder[1];
    final firstTeam = firstSeat % 2;
    final secondTeam = secondSeat % 2;

    int advancement = 0;
    if (firstTeam == secondTeam) {
      // 双上: both from same team finished 1st and 2nd
      advancement = 3;
    } else {
      // Check where the first team's partner finished
      final partnerSeat = finishOrder.indexWhere(
          (s) => s % 2 == firstTeam && s != firstSeat);
      final partnerPlace = partnerSeat; // index in finishOrder = place-1
      if (partnerPlace == 2) {
        advancement = 2; // partner was 3rd
      } else {
        advancement = 1; // partner was 4th
      }
    }

    // Advance the winning team
    final beforeValue = teamLevels[firstTeam]!.value;
    final newLevel = _advanceLevel(teamLevels[firstTeam]!, advancement);
    teamLevels[firstTeam] = newLevel;

    final after = Map<int, int>.from(
        teamLevels.map((k, v) => MapEntry(k, v.value)));

    // Check if game is over (past Ace)
    // _advanceLevel caps at Ace, so check raw arithmetic instead
    int? winner;
    if (beforeValue + advancement > Rank.ace.value) {
      winner = firstTeam;
      phase = GamePhase.gameEnd;
    }

    return RoundResult(
      finishOrder: finishOrder,
      teamLevelsBefore: before,
      teamLevelsAfter: after,
      winningTeam: winner,
    );
  }

  // ── Private Helpers ──

  void _validateTurn(int seatIndex) {
    if (seatIndex != currentPlayer) {
      throw StateError(
          'Not your turn (current: $currentPlayer, got: $seatIndex)');
    }
  }

  void _validateOwnership(int seatIndex, List<GameCard> cards) {
    final hand = List<GameCard>.from(hands[seatIndex]);
    for (final card in cards) {
      final idx = hand.indexWhere((c) => c == card);
      if (idx == -1) {
        throw ArgumentError('You do not have card ${card.key}');
      }
      hand.removeAt(idx);
    }
  }

  void _removeCards(int seatIndex, List<GameCard> cards) {
    for (final card in cards) {
      hands[seatIndex].remove(card);
    }
  }

  void _advanceToNextPlayer() {
    int next = currentPlayer;
    for (int i = 0; i < 4; i++) {
      next = (next + 1) % 4;
      // Skip finished players
      if (hands[next].isNotEmpty) {
        // Skip if this is the trick leader returning to themselves
        // (shouldn't happen normally, but safety check)
        currentPlayer = next;
        return;
      }
    }
    // If we get here, all players are done (shouldn't happen in normal flow)
    currentPlayer = next;
  }

  void _startNewTrick() {
    currentTrick = null;
    consecutivePasses = 0;
    lastPlay = {0: null, 1: null, 2: null, 3: null};
    passedThisTrick = {0: false, 1: false, 2: false, 3: false};

    // Trick leader leads next
    if (hands[trickLeader].isNotEmpty) {
      currentPlayer = trickLeader;
    } else {
      // Leader already finished, advance from their position
      currentPlayer = trickLeader;
      _advanceToNextPlayer();
    }
  }

  int _countActivePlayers() {
    int count = 0;
    for (int i = 0; i < 4; i++) {
      if (hands[i].isNotEmpty) count++;
    }
    return count;
  }

  Rank _advanceLevel(Rank current, int steps) {
    // Rank progression: 2,3,4,5,6,7,8,9,10,J,Q,K,A
    // Values: 2-14
    final newValue = current.value + steps;
    if (newValue > Rank.ace.value) {
      // Past ace = game won (return a sentinel)
      return Rank.ace; // caller checks via winningTeam
    }
    return Rank.fromValue(newValue);
  }

  int _compareCards(GameCard a, GameCard b) {
    final ra = a.effectiveRank(currentLevel);
    final rb = b.effectiveRank(currentLevel);
    if (ra != rb) return ra.compareTo(rb);
    // Secondary: sort by suit
    final sa = a.suit?.index ?? 99;
    final sb = b.suit?.index ?? 99;
    return sa.compareTo(sb);
  }
}
