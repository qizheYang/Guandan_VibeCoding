import 'dart:math';

import 'package:test/test.dart';
import 'package:guandan_shared/guandan_shared.dart';

/// Simulates a full 4-player game through the GameEngine directly.
/// This tests the complete game flow: dealing, playing, passing, trick
/// resolution, round completion, and level advancement.
void main() {
  group('4-Player Full Game Simulation', () {
    test('complete game with simple bot strategy plays to completion', () {
      final teamLevels = {0: Rank.two, 1: Rank.two};
      var totalRounds = 0;

      while (totalRounds < 50) {
        totalRounds++;
        final engine = GameEngine(
          teamLevels: Map.from(teamLevels),
          rng: Random(totalRounds * 7 + 3),
        );
        engine.deal(firstPlayerOverride: totalRounds % 4);

        _playSmartRound(engine);

        expect(engine.phase, GamePhase.roundEnd,
            reason: 'Round $totalRounds should complete');
        expect(engine.finishOrder.length, 4);
        expect(engine.finishOrder.toSet(), {0, 1, 2, 3});

        final result = engine.calculateRoundResult();

        // Update levels
        for (final entry in engine.teamLevels.entries) {
          teamLevels[entry.key] = entry.value;
        }

        if (result.winningTeam != null) {
          // Game over! One team won.
          expect(result.winningTeam, anyOf(0, 1));
          break;
        }
      }

      // The game should end within 50 rounds (levels 2→A = max 13 levels)
      expect(totalRounds, lessThanOrEqualTo(50));
    });

    test('10 independent games all complete successfully', () {
      for (int game = 0; game < 10; game++) {
        final teamLevels = {0: Rank.two, 1: Rank.two};
        var rounds = 0;
        bool gameOver = false;

        while (!gameOver && rounds < 50) {
          rounds++;
          final engine = GameEngine(
            teamLevels: Map.from(teamLevels),
            rng: Random(game * 1000 + rounds),
          );
          engine.deal(firstPlayerOverride: rounds % 4);
          _playSmartRound(engine);

          expect(engine.phase, GamePhase.roundEnd,
              reason: 'Game $game round $rounds');
          final result = engine.calculateRoundResult();

          for (final entry in engine.teamLevels.entries) {
            teamLevels[entry.key] = entry.value;
          }

          if (result.winningTeam != null) gameOver = true;
        }

        expect(gameOver, true, reason: 'Game $game should complete');
      }
    });

    test('hands are always valid after dealing', () {
      for (int seed = 0; seed < 20; seed++) {
        final engine = GameEngine(rng: Random(seed));
        engine.deal();

        // 27 cards each
        for (int i = 0; i < 4; i++) {
          expect(engine.hands[i].length, 27,
              reason: 'Seed $seed: Player $i hand size');
        }

        // Total 108 unique cards
        final allKeys = <String>{};
        for (final hand in engine.hands) {
          for (final card in hand) {
            expect(allKeys.add(card.key), true,
                reason: 'Seed $seed: Duplicate card ${card.key}');
          }
        }
        expect(allKeys.length, 108);
      }
    });

    test('flip card is always in the receiving player hand', () {
      for (int seed = 0; seed < 20; seed++) {
        final engine = GameEngine(rng: Random(seed));
        engine.deal();

        final flip = engine.flipCard!;
        final receiverHand = engine.hands[flip.receiverSeat];
        expect(receiverHand.contains(flip.card), true,
            reason:
                'Seed $seed: Flip card ${flip.card.key} not in seat ${flip.receiverSeat}');
      }
    });

    test('card counts decrease correctly during play', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      final initialCounts = List.generate(4, (i) => engine.hands[i].length);
      expect(initialCounts, [27, 27, 27, 27]);

      // Player 0 plays one card
      engine.playCards(0, [engine.hands[0].first]);
      expect(engine.hands[0].length, 26);
      expect(engine.hands[1].length, 27);
    });

    test('no card duplication during play', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // Track all played cards
      final played = <String>{};
      var moves = 0;

      while (engine.phase == GamePhase.playing && moves < 500) {
        moves++;
        final seat = engine.currentPlayer;
        final hand = engine.hands[seat];
        if (hand.isEmpty) break;

        if (engine.currentTrick == null) {
          final card = hand.first;
          played.add(card.key);
          engine.playCards(seat, [card]);
        } else if (engine.currentTrick!.type == ComboType.single) {
          final currentRank = engine.currentTrick!.primaryRank;
          final beater = hand
              .where((c) =>
                  c.effectiveRank(engine.currentLevel) > currentRank)
              .toList();
          if (beater.isNotEmpty) {
            final card = beater.first;
            expect(played.contains(card.key), false,
                reason: 'Card ${card.key} played twice');
            played.add(card.key);
            engine.playCards(seat, [card]);
          } else {
            engine.pass(seat);
          }
        } else {
          engine.pass(seat);
        }
      }
    });

    test('trick resolution: all pass returns to leader', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // P0 plays
      engine.playCards(0, [engine.hands[0].first]);
      expect(engine.trickLeader, 0);

      // All others pass
      engine.pass(1);
      engine.pass(2);
      engine.pass(3);

      // Trick won by P0, new trick
      expect(engine.currentTrick, isNull);
      expect(engine.currentPlayer, 0);
    });

    test('finished player is skipped in turn order', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // Give player 0 only 1 card
      engine.hands[0] = [engine.hands[0].first];
      engine.playCards(0, [engine.hands[0].first]);

      // Player 0 has finished
      expect(engine.finishOrder, contains(0));

      // Turn should go to player 1 (or next active player)
      expect(engine.hands[engine.currentPlayer].isNotEmpty, true);
    });

    test('round result: double finish scores +3', () {
      final engine = GameEngine(
        teamLevels: {0: Rank.two, 1: Rank.two},
        rng: Random(42),
      );
      engine.deal(firstPlayerOverride: 0);
      engine.currentLevel = Rank.two;

      // Force finish order: team 0 gets 1st and 2nd
      engine.finishOrder = [0, 2, 1, 3];
      engine.phase = GamePhase.roundEnd;

      final result = engine.calculateRoundResult();
      // Team 0 (seats 0,2) finished 1st,2nd → +3
      expect(result.teamLevelsAfter[0], Rank.five.value); // 2+3=5
      expect(result.teamLevelsAfter[1], Rank.two.value); // unchanged
    });

    test('round result: split 1st/3rd scores +2', () {
      final engine = GameEngine(
        teamLevels: {0: Rank.two, 1: Rank.two},
      );
      engine.currentLevel = Rank.two;
      engine.hands = List.generate(4, (_) => []);
      engine.finishOrder = [0, 1, 2, 3];
      // P0(team0)=1st, P1(team1)=2nd, P2(team0)=3rd, P3(team1)=4th

      final result = engine.calculateRoundResult();
      expect(result.teamLevelsAfter[0], Rank.four.value); // 2+2=4
    });

    test('round result: split 1st/4th scores +1', () {
      final engine = GameEngine(
        teamLevels: {0: Rank.two, 1: Rank.two},
      );
      engine.currentLevel = Rank.two;
      engine.hands = List.generate(4, (_) => []);
      engine.finishOrder = [0, 1, 3, 2];
      // P0(team0)=1st, P1(team1)=2nd, P3(team1)=3rd, P2(team0)=4th

      final result = engine.calculateRoundResult();
      expect(result.teamLevelsAfter[0], Rank.three.value); // 2+1=3
    });

    test('team 1 winning scenario', () {
      final engine = GameEngine(
        teamLevels: {0: Rank.two, 1: Rank.two},
      );
      engine.currentLevel = Rank.two;
      engine.hands = List.generate(4, (_) => []);
      engine.finishOrder = [1, 3, 0, 2];
      // P1(team1)=1st, P3(team1)=2nd → team 1 双上

      final result = engine.calculateRoundResult();
      expect(result.teamLevelsAfter[1], Rank.five.value); // 2+3=5
      expect(result.teamLevelsAfter[0], Rank.two.value);
    });

    test('bomb beats non-bomb during play', () {
      final engine = GameEngine(rng: Random(42));
      engine.deal(firstPlayerOverride: 0);

      // Find a single in P0's hand
      final card0 = engine.hands[0].first;
      engine.playCards(0, [card0]);

      // Find 4-of-a-kind in P1's hand
      final hand1 = engine.hands[1];
      final groups = <int, List<GameCard>>{};
      for (final c in hand1) {
        if (!c.isJoker) {
          final r = c.effectiveRank(engine.currentLevel);
          groups.putIfAbsent(r, () => []).add(c);
        }
      }

      final bombGroup = groups.entries.where((e) => e.value.length >= 4);
      if (bombGroup.isNotEmpty) {
        final bombCards = bombGroup.first.value.sublist(0, 4);
        final combo = engine.playCards(1, bombCards);
        expect(combo.isBomb, true);
      }
    });

    test('wild card substitution in play', () {
      // Create engine at level 5
      final engine = GameEngine(
        teamLevels: {0: Rank.five, 1: Rank.five},
        rng: Random(42),
      );
      engine.deal(firstPlayerOverride: 0);

      // Check that h5 cards are wild
      final wilds = engine.hands[0]
          .where((c) => c.isWild(engine.currentLevel))
          .toList();
      // Wilds exist (heart 5 cards) - there should be 0-2 in any hand
      expect(wilds.length, lessThanOrEqualTo(2));

      // If we have a wild, it can pair with any other card
      if (wilds.isNotEmpty) {
        final wild = wilds.first;
        final other = engine.hands[0]
            .firstWhere((c) => !c.isWild(engine.currentLevel) && !c.isJoker);
        final combo = ComboDetector.detect([wild, other], engine.currentLevel);
        expect(combo, isNotNull);
        expect(combo!.type, ComboType.pair);
      }
    });
  });

  group('Stress Tests', () {
    test('100 random deals all produce valid hands', () {
      for (int i = 0; i < 100; i++) {
        final engine = GameEngine(rng: Random(i));
        engine.deal();

        final allCards = engine.hands.expand((h) => h).toList();
        expect(allCards.length, 108, reason: 'Seed $i');

        // All card keys unique
        final keys = allCards.map((c) => c.key).toSet();
        expect(keys.length, 108, reason: 'Seed $i duplicate cards');
      }
    });

    test('100 random games complete without errors', () {
      for (int i = 0; i < 100; i++) {
        final engine = GameEngine(rng: Random(i));
        engine.deal(firstPlayerOverride: i % 4);

        try {
          _playSmartRound(engine);
          expect(engine.phase, GamePhase.roundEnd, reason: 'Seed $i');
          expect(engine.finishOrder.length, 4, reason: 'Seed $i');
        } catch (e) {
          fail('Seed $i failed: $e');
        }
      }
    });
  });
}

/// Smart bot strategy that uses singles, pairs, and bombs.
void _playSmartRound(GameEngine engine) {
  var moves = 0;
  while (engine.phase == GamePhase.playing && moves < 1000) {
    moves++;
    final seat = engine.currentPlayer;
    final hand = engine.hands[seat];
    if (hand.isEmpty) break;

    if (engine.currentTrick == null) {
      // Leading: try bombs, then pairs, then singles
      if (!_tryPlayBomb(engine, seat)) {
        if (!_tryPlayPair(engine, seat)) {
          engine.playCards(seat, [hand.first]);
        }
      }
    } else {
      // Following
      final trick = engine.currentTrick!;

      if (trick.type == ComboType.single) {
        final beater = hand
            .where((c) =>
                c.effectiveRank(engine.currentLevel) > trick.primaryRank)
            .toList();
        if (beater.isNotEmpty) {
          engine.playCards(seat, [beater.first]);
        } else if (!_tryPlayBomb(engine, seat)) {
          engine.pass(seat);
        }
      } else if (trick.type == ComboType.pair) {
        if (!_tryBeatPair(engine, seat, trick.primaryRank)) {
          if (!_tryPlayBomb(engine, seat)) {
            engine.pass(seat);
          }
        }
      } else if (trick.isBomb) {
        // Try to beat with a bigger bomb
        if (!_tryBeatBomb(engine, seat, trick)) {
          engine.pass(seat);
        }
      } else {
        // For other combo types, just pass for simplicity
        engine.pass(seat);
      }
    }
  }

  if (moves >= 1000) {
    fail('Round did not complete within 1000 moves');
  }
}

bool _tryPlayPair(GameEngine engine, int seat) {
  final hand = engine.hands[seat];
  final level = engine.currentLevel;

  final groups = <int, List<GameCard>>{};
  for (final c in hand) {
    final r = c.effectiveRank(level);
    groups.putIfAbsent(r, () => []).add(c);
  }

  // Play lowest pair
  final pairs = groups.entries.where((e) => e.value.length >= 2).toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  for (final entry in pairs) {
    final pair = entry.value.sublist(0, 2);
    final combo = ComboDetector.detect(pair, level);
    if (combo != null && combo.type == ComboType.pair) {
      engine.playCards(seat, pair);
      return true;
    }
  }
  return false;
}

bool _tryBeatPair(GameEngine engine, int seat, int currentRank) {
  final hand = engine.hands[seat];
  final level = engine.currentLevel;

  final groups = <int, List<GameCard>>{};
  for (final c in hand) {
    final r = c.effectiveRank(level);
    groups.putIfAbsent(r, () => []).add(c);
  }

  final candidates = groups.entries
      .where((e) => e.key > currentRank && e.value.length >= 2)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  for (final entry in candidates) {
    final pair = entry.value.sublist(0, 2);
    final combo = ComboDetector.detect(pair, level);
    if (combo != null) {
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

bool _tryPlayBomb(GameEngine engine, int seat) {
  final hand = engine.hands[seat];
  final level = engine.currentLevel;

  final groups = <int, List<GameCard>>{};
  for (final c in hand) {
    if (!c.isJoker) {
      final r = c.effectiveRank(level);
      groups.putIfAbsent(r, () => []).add(c);
    }
  }

  // Find smallest bomb (4 of a kind)
  final bombGroups = groups.entries.where((e) => e.value.length >= 4).toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  if (bombGroups.isNotEmpty) {
    final bombCards = bombGroups.first.value.sublist(0, 4);
    try {
      engine.playCards(seat, bombCards);
      return true;
    } catch (_) {}
  }
  return false;
}

bool _tryBeatBomb(GameEngine engine, int seat, CardCombo currentBomb) {
  final hand = engine.hands[seat];
  final level = engine.currentLevel;

  // Try bigger bomb of same size
  final groups = <int, List<GameCard>>{};
  for (final c in hand) {
    if (!c.isJoker) {
      final r = c.effectiveRank(level);
      groups.putIfAbsent(r, () => []).add(c);
    }
  }

  final bombSize = currentBomb.cards.length;
  final candidates = groups.entries
      .where((e) =>
          e.value.length >= bombSize && e.key > currentBomb.primaryRank)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  if (candidates.isNotEmpty) {
    final bombCards = candidates.first.value.sublist(0, bombSize);
    try {
      engine.playCards(seat, bombCards);
      return true;
    } catch (_) {}
  }

  // Try bigger bomb size
  for (int size = bombSize + 1; size <= 8; size++) {
    final biggerBombs = groups.entries
        .where((e) => e.value.length >= size)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (biggerBombs.isNotEmpty) {
      final bombCards = biggerBombs.first.value.sublist(0, size);
      try {
        engine.playCards(seat, bombCards);
        return true;
      } catch (_) {}
    }
  }

  return false;
}
