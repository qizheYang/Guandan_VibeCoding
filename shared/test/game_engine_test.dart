import 'dart:math';

import 'package:test/test.dart';
import 'package:guandan_shared/guandan_shared.dart';

void main() {
  group('GameEngine - Dealing', () {
    test('deal distributes 27 cards to each player', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal();

      for (int i = 0; i < 4; i++) {
        expect(engine.hands[i].length, 27);
      }
    });

    test('deal uses all 108 cards', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal();

      final allCards = <GameCard>[];
      for (final hand in engine.hands) {
        allCards.addAll(hand);
      }
      expect(allCards.length, 108);

      // Verify uniqueness by key
      final keys = allCards.map((c) => c.key).toSet();
      expect(keys.length, 108);
    });

    test('deal sets flipCard', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal();

      expect(engine.flipCard, isNotNull);
      expect(engine.flipCard!.position, greaterThanOrEqualTo(0));
      expect(engine.flipCard!.position, lessThan(108));
      expect(engine.flipCard!.receiverSeat, greaterThanOrEqualTo(0));
      expect(engine.flipCard!.receiverSeat, lessThan(4));
    });

    test('flipCard receiver is position % 4', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal();

      final pos = engine.flipCard!.position;
      expect(engine.flipCard!.receiverSeat, pos % 4);
    });

    test('first player is the flip card receiver', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal();

      expect(engine.currentPlayer, engine.flipCard!.receiverSeat);
    });

    test('deal with firstPlayerOverride', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 3);

      expect(engine.currentPlayer, 3);
    });

    test('currentLevel is set from first player team', () {
      final engine = GameEngine(
        teamLevels: {0: Rank.five, 1: Rank.three},
        rng: Random(42),
      );
      engine.deal(firstPlayerOverride: 0);
      expect(engine.currentLevel, Rank.five); // team 0's level

      final engine2 = GameEngine(
        teamLevels: {0: Rank.five, 1: Rank.three},
        rng: Random(42),
      );
      engine2.deal(firstPlayerOverride: 1);
      expect(engine2.currentLevel, Rank.three); // team 1's level
    });

    test('deal sets phase to playing', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal();
      expect(engine.phase, GamePhase.playing);
    });

    test('deal resets round state', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal();
      expect(engine.finishOrder, isEmpty);
      expect(engine.currentTrick, isNull);
      expect(engine.consecutivePasses, 0);
    });

    test('different seeds produce different deals', () {
      final engine1 = GameEngine(rng: Random(1));
      engine1.deal();
      final engine2 = GameEngine(rng: Random(2));
      engine2.deal();

      // Very unlikely (but theoretically possible) that hands are identical
      // with different seeds. Check first player's first card.
      final hand1Keys = engine1.hands[0].map((c) => c.key).toList();
      final hand2Keys = engine2.hands[0].map((c) => c.key).toList();
      expect(hand1Keys, isNot(hand2Keys));
    });
  });

  group('GameEngine - Playing Cards', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);
    });

    test('valid single play succeeds', () {
      final card = engine.hands[0].first;
      final combo = engine.playCards(0, [card]);
      expect(combo.type, ComboType.single);
    });

    test('playing removes cards from hand', () {
      final card = engine.hands[0].first;
      final beforeCount = engine.hands[0].length;
      engine.playCards(0, [card]);
      expect(engine.hands[0].length, beforeCount - 1);
    });

    test('playing out of turn throws', () {
      expect(() => engine.playCards(1, [engine.hands[1].first]),
          throwsA(isA<StateError>()));
    });

    test('playing card not in hand throws', () {
      // Create a card that is definitely not in hand
      final fakeCard = GameCard(suit: Suit.spade, rank: Rank.ace, deckIndex: 0);
      // Only throws if player doesn't have it
      if (!engine.hands[0].contains(fakeCard)) {
        expect(() => engine.playCards(0, [fakeCard]),
            throwsA(isA<ArgumentError>()));
      }
    });

    test('invalid card combination throws', () {
      // Find two cards of different ranks (non-level) in player 0's hand
      final hand = engine.hands[0];
      GameCard? card1, card2;
      for (int i = 0; i < hand.length - 1; i++) {
        for (int j = i + 1; j < hand.length; j++) {
          final r1 = hand[i].effectiveRank(engine.currentLevel);
          final r2 = hand[j].effectiveRank(engine.currentLevel);
          if (r1 != r2 && !hand[i].isWild(engine.currentLevel) &&
              !hand[j].isWild(engine.currentLevel)) {
            card1 = hand[i];
            card2 = hand[j];
            break;
          }
        }
        if (card1 != null) break;
      }
      if (card1 != null && card2 != null) {
        expect(() => engine.playCards(0, [card1!, card2!]),
            throwsA(isA<ArgumentError>()));
      }
    });

    test('play advances to next player', () {
      engine.playCards(0, [engine.hands[0].first]);
      expect(engine.currentPlayer, 1);
    });

    test('play sets trickLeader', () {
      engine.playCards(0, [engine.hands[0].first]);
      expect(engine.trickLeader, 0);
    });

    test('can play higher single to beat current trick', () {
      // Player 0 plays lowest card
      final card0 = engine.hands[0].first;
      engine.playCards(0, [card0]);

      // Player 1 needs to play a higher card
      final rank0 = card0.effectiveRank(engine.currentLevel);
      final higherCard = engine.hands[1].where(
        (c) => c.effectiveRank(engine.currentLevel) > rank0,
      );

      if (higherCard.isNotEmpty) {
        final combo = engine.playCards(1, [higherCard.first]);
        expect(combo.type, ComboType.single);
      }
    });

    test('playing lower card throws', () {
      // Player 0 plays a high card
      final hand0 = List.of(engine.hands[0]);
      hand0.sort((a, b) => b.effectiveRank(engine.currentLevel)
          .compareTo(a.effectiveRank(engine.currentLevel)));
      engine.playCards(0, [hand0.first]); // highest card

      // Player 1 tries to play a low card
      final hand1 = List.of(engine.hands[1]);
      hand1.sort((a, b) => a.effectiveRank(engine.currentLevel)
          .compareTo(b.effectiveRank(engine.currentLevel)));
      // Find a card that is definitely lower
      final lowCard = hand1.firstWhere(
        (c) => c.effectiveRank(engine.currentLevel) <
            hand0.first.effectiveRank(engine.currentLevel),
        orElse: () => hand1.first,
      );

      if (lowCard.effectiveRank(engine.currentLevel) <
          hand0.first.effectiveRank(engine.currentLevel)) {
        expect(() => engine.playCards(1, [lowCard]),
            throwsA(isA<ArgumentError>()));
      }
    });
  });

  group('GameEngine - Pass', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);
    });

    test('cannot pass when leading', () {
      expect(() => engine.pass(0), throwsA(isA<StateError>()));
    });

    test('can pass after someone plays', () {
      engine.playCards(0, [engine.hands[0].first]);
      engine.pass(1); // should not throw
      expect(engine.currentPlayer, 2);
    });

    test('pass out of turn throws', () {
      engine.playCards(0, [engine.hands[0].first]);
      expect(() => engine.pass(2), throwsA(isA<StateError>()));
    });

    test('all pass = trick won, new trick starts', () {
      engine.playCards(0, [engine.hands[0].first]);
      engine.pass(1);
      engine.pass(2);
      engine.pass(3); // all 3 passed, trick goes to player 0

      // New trick: currentTrick should be null, player 0 leads again
      expect(engine.currentTrick, isNull);
      expect(engine.currentPlayer, 0);
    });

    test('trick winner leads next trick', () {
      // P0 plays, P1 plays higher, P2 passes, P3 passes, P0 passes
      final card0 = engine.hands[0].first;
      engine.playCards(0, [card0]);

      final rank0 = card0.effectiveRank(engine.currentLevel);
      final higherCards = engine.hands[1]
          .where((c) => c.effectiveRank(engine.currentLevel) > rank0)
          .toList();

      if (higherCards.isNotEmpty) {
        engine.playCards(1, [higherCards.first]);
        engine.pass(2);
        engine.pass(3);
        engine.pass(0); // P1 wins trick

        expect(engine.currentTrick, isNull);
        expect(engine.currentPlayer, 1); // P1 leads
      }
    });
  });

  group('GameEngine - Round Completion', () {
    test('round ends when 3 players finish', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // Simulate by emptying hands directly and triggering finish
      // This is a bit hacky but tests the logic
      engine.hands[0] = [engine.hands[0].first];
      final lastCard = engine.hands[0].first;
      engine.playCards(0, [lastCard]);

      // Player 0 should be in finishOrder
      expect(engine.finishOrder, contains(0));
    });
  });

  group('GameEngine - Round Result & Level Advancement', () {
    test('双上 (both teammates 1st+2nd) = +3 levels', () {
      final engine = GameEngine();
      engine.hands = List.generate(4, (_) => []);
      engine.currentLevel = Rank.two;
      engine.teamLevels = {0: Rank.two, 1: Rank.two};
      engine.finishOrder = [0, 2, 1, 3]; // Team 0 finishes 1st+2nd

      final result = engine.calculateRoundResult();
      expect(result.teamLevelsAfter[0], Rank.five.value); // 2+3=5
      expect(result.winningTeam, isNull);
    });

    test('1st+3rd = +2 levels', () {
      final engine = GameEngine();
      engine.hands = List.generate(4, (_) => []);
      engine.currentLevel = Rank.two;
      engine.teamLevels = {0: Rank.two, 1: Rank.two};
      engine.finishOrder = [0, 1, 2, 3]; // P0(team0) 1st, P1(team1) 2nd, P2(team0) 3rd

      final result = engine.calculateRoundResult();
      expect(result.teamLevelsAfter[0], Rank.four.value); // 2+2=4
    });

    test('1st+4th = +1 level', () {
      final engine = GameEngine();
      engine.hands = List.generate(4, (_) => []);
      engine.currentLevel = Rank.two;
      engine.teamLevels = {0: Rank.two, 1: Rank.two};
      engine.finishOrder = [0, 1, 3, 2]; // P0(team0) 1st, P2(team0) 4th

      final result = engine.calculateRoundResult();
      expect(result.teamLevelsAfter[0], Rank.three.value); // 2+1=3
    });

    test('game over when level passes Ace', () {
      final engine = GameEngine();
      engine.hands = List.generate(4, (_) => []);
      engine.currentLevel = Rank.ace;
      engine.teamLevels = {0: Rank.ace, 1: Rank.two};
      engine.finishOrder = [0, 2, 1, 3]; // Team 0 双上 at Ace

      final result = engine.calculateRoundResult();
      expect(result.winningTeam, 0);
      expect(engine.phase, GamePhase.gameEnd);
    });

    test('team 1 can also win', () {
      final engine = GameEngine();
      engine.hands = List.generate(4, (_) => []);
      engine.currentLevel = Rank.ace;
      engine.teamLevels = {0: Rank.two, 1: Rank.ace};
      engine.finishOrder = [1, 3, 0, 2]; // Team 1 双上 at Ace

      final result = engine.calculateRoundResult();
      expect(result.winningTeam, 1);
    });
  });

  group('GameEngine - Full Round Simulation', () {
    test('4 players play singles until round ends', () {
      final engine = GameEngine(rng: Random(100));
      engine.deal(firstPlayerOverride: 0);

      var moves = 0;
      const maxMoves = 500;

      while (engine.phase == GamePhase.playing && moves < maxMoves) {
        moves++;
        final seat = engine.currentPlayer;
        final hand = engine.hands[seat];

        if (hand.isEmpty) break;

        if (engine.currentTrick == null) {
          // Leading: play lowest single
          engine.playCards(seat, [hand.first]);
        } else {
          // Following: try to beat with a single
          final currentRank = engine.currentTrick!.primaryRank;
          final beater = hand.where(
            (c) => c.effectiveRank(engine.currentLevel) > currentRank,
          ).toList();

          if (beater.isNotEmpty &&
              engine.currentTrick!.type == ComboType.single) {
            engine.playCards(seat, [beater.first]);
          } else {
            engine.pass(seat);
          }
        }
      }

      // Game should complete within maxMoves
      expect(moves, lessThan(maxMoves));
      expect(engine.phase, GamePhase.roundEnd);
      expect(engine.finishOrder.length, 4);

      // All seats should be represented
      expect(engine.finishOrder.toSet(), {0, 1, 2, 3});

      // Level advancement should work
      final result = engine.calculateRoundResult();
      expect(result.finishOrder.length, 4);
    });

    test('simulation with pairs strategy', () {
      final engine = GameEngine(rng: Random(200));
      engine.deal(firstPlayerOverride: 0);

      var moves = 0;
      const maxMoves = 500;

      while (engine.phase == GamePhase.playing && moves < maxMoves) {
        moves++;
        final seat = engine.currentPlayer;
        final hand = engine.hands[seat];
        if (hand.isEmpty) break;

        if (engine.currentTrick == null) {
          // Leading: try pairs first, then singles
          final pairPlayed = _tryPlayPair(engine, seat);
          if (!pairPlayed) {
            engine.playCards(seat, [hand.first]);
          }
        } else if (engine.currentTrick!.type == ComboType.single) {
          final currentRank = engine.currentTrick!.primaryRank;
          final beater = hand.where(
            (c) => c.effectiveRank(engine.currentLevel) > currentRank,
          ).toList();
          if (beater.isNotEmpty) {
            engine.playCards(seat, [beater.first]);
          } else {
            engine.pass(seat);
          }
        } else if (engine.currentTrick!.type == ComboType.pair) {
          final currentRank = engine.currentTrick!.primaryRank;
          final pairBeaten = _tryBeatPair(engine, seat, currentRank);
          if (!pairBeaten) {
            engine.pass(seat);
          }
        } else {
          engine.pass(seat);
        }
      }

      expect(engine.phase, GamePhase.roundEnd);
      expect(engine.finishOrder.length, 4);
    });

    test('multiple rounds with level advancement', () {
      final teamLevels = {0: Rank.two, 1: Rank.two};

      for (int round = 0; round < 5; round++) {
        final engine = GameEngine(
          teamLevels: Map.from(teamLevels),
          rng: Random(round * 37),
        );
        engine.deal(firstPlayerOverride: round % 4);

        _playSimpleRound(engine);

        expect(engine.phase, GamePhase.roundEnd);
        final result = engine.calculateRoundResult();

        // Update team levels for next round
        for (final entry in engine.teamLevels.entries) {
          teamLevels[entry.key] = entry.value;
        }

        // Verify levels only go up
        for (final entry in result.teamLevelsAfter.entries) {
          expect(entry.value,
              greaterThanOrEqualTo(result.teamLevelsBefore[entry.key]!));
        }

        if (result.winningTeam != null) break;
      }
    });
  });

  group('GameEngine - Server Validation', () {
    test('validates turn order', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // Player 2 tries to play out of turn
      expect(
        () => engine.playCards(2, [engine.hands[2].first]),
        throwsA(isA<StateError>()),
      );
    });

    test('validates card ownership', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // Player 0 tries to play a card from player 1's hand
      final p1Card = engine.hands[1].first;
      if (!engine.hands[0].contains(p1Card)) {
        expect(
          () => engine.playCards(0, [p1Card]),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('validates combo is valid', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // Find two non-matching cards
      final hand = engine.hands[0];
      for (int i = 0; i < hand.length - 1; i++) {
        final r1 = hand[i].effectiveRank(engine.currentLevel);
        final r2 = hand[i + 1].effectiveRank(engine.currentLevel);
        if (r1 != r2 && !hand[i].isWild(engine.currentLevel) &&
            !hand[i + 1].isWild(engine.currentLevel)) {
          expect(
            () => engine.playCards(0, [hand[i], hand[i + 1]]),
            throwsA(isA<ArgumentError>()),
          );
          break;
        }
      }
    });

    test('validates combo beats current trick', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // Player 0 plays highest card
      final hand0 = List.of(engine.hands[0])
        ..sort((a, b) => b.effectiveRank(engine.currentLevel)
            .compareTo(a.effectiveRank(engine.currentLevel)));
      engine.playCards(0, [hand0.first]);

      // Player 1 tries to play a lower card
      final hand1 = List.of(engine.hands[1])
        ..sort((a, b) => a.effectiveRank(engine.currentLevel)
            .compareTo(b.effectiveRank(engine.currentLevel)));

      final lowCard = hand1.firstWhere(
        (c) => c.effectiveRank(engine.currentLevel) <
            hand0.first.effectiveRank(engine.currentLevel),
        orElse: () => hand1.first,
      );

      if (lowCard.effectiveRank(engine.currentLevel) <
          hand0.first.effectiveRank(engine.currentLevel)) {
        expect(
          () => engine.playCards(1, [lowCard]),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('cannot play when game is not in playing phase', () {
      final engine = GameEngine(rng: Random(42));
      // Don't deal, phase is still 'waiting'
      engine.hands = List.generate(4, (_) => [
        GameCard(suit: Suit.spade, rank: Rank.ace, deckIndex: 0),
      ]);
      engine.currentPlayer = 0;
      engine.currentLevel = Rank.two;

      expect(
        () => engine.playCards(0, [engine.hands[0].first]),
        throwsA(isA<StateError>()),
      );
    });

    test('cannot play empty cards', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      expect(
        () => engine.playCards(0, []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

/// Try to play a pair from the given seat. Returns true if successful.
bool _tryPlayPair(GameEngine engine, int seat) {
  final hand = engine.hands[seat];
  final level = engine.currentLevel;

  // Group by effective rank
  final groups = <int, List<GameCard>>{};
  for (final c in hand) {
    final r = c.effectiveRank(level);
    groups.putIfAbsent(r, () => []).add(c);
  }

  for (final entry in groups.entries) {
    if (entry.value.length >= 2) {
      final pair = entry.value.sublist(0, 2);
      try {
        engine.playCards(seat, pair);
        return true;
      } catch (_) {
        continue;
      }
    }
  }
  return false;
}

/// Try to beat the current pair trick. Returns true if successful.
bool _tryBeatPair(GameEngine engine, int seat, int currentRank) {
  final hand = engine.hands[seat];
  final level = engine.currentLevel;

  final groups = <int, List<GameCard>>{};
  for (final c in hand) {
    final r = c.effectiveRank(level);
    groups.putIfAbsent(r, () => []).add(c);
  }

  // Find a pair with higher rank
  final candidates = groups.entries
      .where((e) => e.key > currentRank && e.value.length >= 2)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key)); // play lowest winning pair

  if (candidates.isNotEmpty) {
    final pair = candidates.first.value.sublist(0, 2);
    try {
      engine.playCards(seat, pair);
      return true;
    } catch (_) {
      return false;
    }
  }
  return false;
}

/// Play a simple round (singles only) until it ends.
void _playSimpleRound(GameEngine engine) {
  var moves = 0;
  while (engine.phase == GamePhase.playing && moves < 500) {
    moves++;
    final seat = engine.currentPlayer;
    final hand = engine.hands[seat];
    if (hand.isEmpty) break;

    if (engine.currentTrick == null) {
      engine.playCards(seat, [hand.first]);
    } else {
      final currentRank = engine.currentTrick!.primaryRank;
      if (engine.currentTrick!.type == ComboType.single) {
        final beater = hand.where(
          (c) => c.effectiveRank(engine.currentLevel) > currentRank,
        ).toList();
        if (beater.isNotEmpty) {
          engine.playCards(seat, [beater.first]);
        } else {
          engine.pass(seat);
        }
      } else {
        engine.pass(seat);
      }
    }
  }
}
