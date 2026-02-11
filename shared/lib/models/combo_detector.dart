import 'card.dart';
import 'card_combo.dart';

class ComboDetector {
  /// Detect what combination the given cards form, or null if invalid.
  static CardCombo? detect(List<GameCard> cards, Rank currentLevel) {
    if (cards.isEmpty) return null;

    // Separate wilds from natural cards
    final wilds = <GameCard>[];
    final naturals = <GameCard>[];
    for (final c in cards) {
      if (c.isWild(currentLevel)) {
        wilds.add(c);
      } else {
        naturals.add(c);
      }
    }

    // Try each combo type (order matters: try bombs first for ambiguous cases)
    final n = cards.length;

    // Joker bomb: exactly 4 jokers
    if (n == 4) {
      final r = _detectJokerBomb(cards);
      if (r != null) return r;
    }

    // Straight flush (5 cards, same suit, consecutive by face value)
    if (n == 5) {
      final r = _detectStraightFlush(naturals, wilds, currentLevel);
      if (r != null) return r;
    }

    // N-of-a-kind bombs (4-8)
    if (n >= 4 && n <= 8) {
      final r = _detectBomb(naturals, wilds, n, currentLevel);
      if (r != null) return r;
    }

    // Single
    if (n == 1) {
      return CardCombo(
        type: ComboType.single,
        cards: cards,
        primaryRank: cards[0].effectiveRank(currentLevel),
      );
    }

    // Pair
    if (n == 2) {
      final r = _detectPair(naturals, wilds, currentLevel);
      if (r != null) return r;
    }

    // Triple
    if (n == 3) {
      final r = _detectTriple(naturals, wilds, currentLevel);
      if (r != null) return r;
    }

    // Full house (5 cards: triple + pair)
    if (n == 5) {
      final r = _detectFullHouse(naturals, wilds, currentLevel);
      if (r != null) return r;
    }

    // Straight (5+ consecutive by face value)
    if (n >= 5) {
      final r = _detectStraight(naturals, wilds, currentLevel);
      if (r != null) return r;
    }

    // Pair sequence / 连对 (6+ cards, 3+ consecutive pairs)
    if (n >= 6 && n % 2 == 0) {
      final r = _detectPairSequence(naturals, wilds, n, currentLevel);
      if (r != null) return r;
    }

    // Triple sequence / 钢板 (6+ cards, 2+ consecutive triples)
    if (n >= 6 && n % 3 == 0) {
      final r = _detectTripleSequence(naturals, wilds, n, currentLevel);
      if (r != null) return r;
    }

    return null;
  }

  /// Check if [combo] can beat [current]. Null current means leading.
  static bool canBeat(CardCombo combo, CardCombo? current) {
    if (current == null) return true; // leading, any combo is valid
    return combo.beats(current);
  }

  // ── Private detection methods ──

  static CardCombo? _detectJokerBomb(List<GameCard> cards) {
    if (cards.length != 4) return null;
    if (cards.every((c) => c.isJoker)) {
      return CardCombo(
        type: ComboType.jokerBomb,
        cards: cards,
        primaryRank: 9999,
      );
    }
    return null;
  }

  static CardCombo? _detectPair(
      List<GameCard> naturals, List<GameCard> wilds, Rank level) {
    final total = naturals.length + wilds.length;
    if (total != 2) return null;

    if (naturals.length == 2) {
      // Both natural, must be same effective rank
      final r0 = naturals[0].effectiveRank(level);
      final r1 = naturals[1].effectiveRank(level);
      if (r0 == r1) {
        return CardCombo(
          type: ComboType.pair,
          cards: [...naturals, ...wilds],
          primaryRank: r0,
        );
      }
      return null;
    }

    // 1 natural + 1 wild, or 2 wilds
    if (naturals.isEmpty) {
      // 2 wilds = pair of level rank
      return CardCombo(
        type: ComboType.pair,
        cards: wilds,
        primaryRank: wilds[0].effectiveRank(level),
      );
    }

    // 1 natural + 1 wild
    return CardCombo(
      type: ComboType.pair,
      cards: [...naturals, ...wilds],
      primaryRank: naturals[0].effectiveRank(level),
    );
  }

  static CardCombo? _detectTriple(
      List<GameCard> naturals, List<GameCard> wilds, Rank level) {
    final total = naturals.length + wilds.length;
    if (total != 3) return null;

    if (naturals.isEmpty) {
      // 3 wilds
      return CardCombo(
        type: ComboType.triple,
        cards: wilds,
        primaryRank: wilds[0].effectiveRank(level),
      );
    }

    // All naturals must have same effective rank
    final ranks = naturals.map((c) => c.effectiveRank(level)).toSet();
    if (ranks.length == 1) {
      return CardCombo(
        type: ComboType.triple,
        cards: [...naturals, ...wilds],
        primaryRank: ranks.first,
      );
    }

    return null;
  }

  static CardCombo? _detectFullHouse(
      List<GameCard> naturals, List<GameCard> wilds, Rank level) {
    final total = naturals.length + wilds.length;
    if (total != 5) return null;

    // Group naturals by effective rank
    final groups = <int, List<GameCard>>{};
    for (final c in naturals) {
      final r = c.effectiveRank(level);
      groups.putIfAbsent(r, () => []).add(c);
    }

    final wildCount = wilds.length;

    // Try each rank as the triple
    final allRanks = groups.keys.toList();
    for (final tripleRank in allRanks) {
      final tripleCount = groups[tripleRank]!.length;
      final wildsNeededForTriple = 3 - tripleCount;
      if (wildsNeededForTriple < 0 || wildsNeededForTriple > wildCount) continue;

      final wildsLeft = wildCount - wildsNeededForTriple;
      // Remaining naturals (not used in triple)
      final remainingNaturalCount =
          naturals.length - groups[tripleRank]!.length;
      final pairSize = remainingNaturalCount + wildsLeft;
      if (pairSize != 2) continue;

      // Remaining naturals must all share a rank (if any)
      if (remainingNaturalCount > 0) {
        final otherRanks = groups.entries
            .where((e) => e.key != tripleRank)
            .expand((e) => e.value)
            .map((c) => c.effectiveRank(level))
            .toSet();
        if (otherRanks.length > 1) continue;
      }

      return CardCombo(
        type: ComboType.fullHouse,
        cards: [...naturals, ...wilds],
        primaryRank: tripleRank,
      );
    }

    // Edge case: wilds form the triple entirely
    if (wildCount >= 3 && naturals.length == 2) {
      final r0 = naturals[0].effectiveRank(level);
      final r1 = naturals[1].effectiveRank(level);
      if (r0 == r1) {
        // 2 naturals as pair, 3 wilds as triple
        final wildRank = wilds[0].effectiveRank(level);
        if (wildRank != r0) {
          return CardCombo(
            type: ComboType.fullHouse,
            cards: [...naturals, ...wilds],
            primaryRank: wildRank,
          );
        }
      }
    }

    return null;
  }

  static CardCombo? _detectStraight(
      List<GameCard> naturals, List<GameCard> wilds, Rank level) {
    final total = naturals.length + wilds.length;
    if (total < 5) return null;

    // Straights use FACE VALUE (not effective rank), and jokers can't be in straights
    if (naturals.any((c) => c.isJoker) || wilds.any((c) => c.isJoker)) {
      return null;
    }

    final wildCount = wilds.length;

    // Get face values of naturals (2-14)
    final faceValues = naturals.map((c) => c.rank.value).toList()..sort();

    // A can be high only (no wrapping in Guan Dan straights)
    // Try all possible starting positions
    // Straight must be consecutive face values of length `total`
    final length = total;

    // Min possible start: max(2, min(faceValues) - wildCount)
    // Max possible start: 14 - length + 1
    for (int start = 2; start <= 14 - length + 1; start++) {
      final needed = <int>{};
      for (int i = 0; i < length; i++) {
        needed.add(start + i);
      }

      // Check if naturals fit (each natural's face value must be in needed set)
      final naturalValues = List<int>.from(faceValues);
      var valid = true;
      var wildsUsed = 0;

      final neededList = needed.toList()..sort();
      final matched = <int>[];

      for (final nv in naturalValues) {
        if (needed.contains(nv) && !matched.contains(nv)) {
          matched.add(nv);
        } else {
          // Check if this natural has a duplicate face value already matched
          // (from 2 decks, can have 2 cards of same rank)
          final countInNaturals =
              naturalValues.where((v) => v == nv).length;
          final countMatched = matched.where((v) => v == nv).length;
          if (countMatched < countInNaturals && countInNaturals <= 1) {
            valid = false;
            break;
          } else if (!needed.contains(nv)) {
            valid = false;
            break;
          }
        }
      }

      if (!valid) continue;

      // Count how many positions aren't covered by naturals
      wildsUsed = 0;
      final naturalValCounts = <int, int>{};
      for (final v in naturalValues) {
        naturalValCounts[v] = (naturalValCounts[v] ?? 0) + 1;
      }

      var ok = true;
      for (final pos in neededList) {
        if (naturalValCounts.containsKey(pos) && naturalValCounts[pos]! > 0) {
          naturalValCounts[pos] = naturalValCounts[pos]! - 1;
        } else {
          wildsUsed++;
        }
      }

      // Check no leftover naturals
      final leftover = naturalValCounts.values.fold(0, (a, b) => a + b);
      if (leftover > 0) continue;

      if (ok && wildsUsed == wildCount) {
        return CardCombo(
          type: ComboType.straight,
          cards: [...naturals, ...wilds],
          primaryRank: start + length - 1, // highest card's face value
        );
      }
    }

    return null;
  }

  static CardCombo? _detectPairSequence(
      List<GameCard> naturals, List<GameCard> wilds, int total, Rank level) {
    if (total < 6 || total % 2 != 0) return null;
    final pairCount = total ~/ 2; // need this many consecutive ranks

    // Jokers can't participate
    if (naturals.any((c) => c.isJoker) || wilds.any((c) => c.isJoker)) {
      return null;
    }

    final wildCount = wilds.length;

    // Group naturals by face value
    final groups = <int, int>{};
    for (final c in naturals) {
      groups[c.rank.value] = (groups[c.rank.value] ?? 0) + 1;
    }

    // Try each starting face value
    for (int start = 2; start <= 14 - pairCount + 1; start++) {
      var wildsNeeded = 0;
      var valid = true;

      for (int i = 0; i < pairCount; i++) {
        final rank = start + i;
        final have = groups[rank] ?? 0;
        if (have > 2) {
          valid = false;
          break;
        }
        wildsNeeded += (2 - have).clamp(0, 2);
      }

      if (!valid) continue;

      // Check no naturals are outside the range
      final totalNaturalsInRange = List.generate(pairCount, (i) => start + i)
          .fold(0, (sum, r) => sum + (groups[r] ?? 0).clamp(0, 2));
      if (totalNaturalsInRange != naturals.length) continue;

      if (wildsNeeded == wildCount) {
        return CardCombo(
          type: ComboType.pairSequence,
          cards: [...naturals, ...wilds],
          primaryRank: start + pairCount - 1,
        );
      }
    }

    return null;
  }

  static CardCombo? _detectTripleSequence(
      List<GameCard> naturals, List<GameCard> wilds, int total, Rank level) {
    if (total < 6 || total % 3 != 0) return null;
    final tripleCount = total ~/ 3;

    if (naturals.any((c) => c.isJoker) || wilds.any((c) => c.isJoker)) {
      return null;
    }

    final wildCount = wilds.length;

    final groups = <int, int>{};
    for (final c in naturals) {
      groups[c.rank.value] = (groups[c.rank.value] ?? 0) + 1;
    }

    for (int start = 2; start <= 14 - tripleCount + 1; start++) {
      var wildsNeeded = 0;
      var valid = true;

      for (int i = 0; i < tripleCount; i++) {
        final rank = start + i;
        final have = groups[rank] ?? 0;
        if (have > 3) {
          valid = false;
          break;
        }
        wildsNeeded += (3 - have).clamp(0, 3);
      }

      if (!valid) continue;

      final totalNaturalsInRange = List.generate(tripleCount, (i) => start + i)
          .fold(0, (sum, r) => sum + (groups[r] ?? 0).clamp(0, 3));
      if (totalNaturalsInRange != naturals.length) continue;

      if (wildsNeeded == wildCount) {
        return CardCombo(
          type: ComboType.tripleSequence,
          cards: [...naturals, ...wilds],
          primaryRank: start + tripleCount - 1,
        );
      }
    }

    return null;
  }

  static CardCombo? _detectBomb(
      List<GameCard> naturals, List<GameCard> wilds, int total, Rank level) {
    if (total < 4 || total > 8) return null;

    // Jokers can't be in regular bombs
    if (naturals.any((c) => c.isJoker)) return null;

    // All naturals must share the same effective rank
    if (naturals.isEmpty) {
      // All wilds - they form a bomb of the level rank
      final bombType = _bombTypeForCount(total);
      if (bombType == null) return null;
      return CardCombo(
        type: bombType,
        cards: wilds,
        primaryRank: wilds[0].effectiveRank(level),
      );
    }

    final ranks = naturals.map((c) => c.effectiveRank(level)).toSet();
    if (ranks.length != 1) return null;

    final bombType = _bombTypeForCount(total);
    if (bombType == null) return null;

    return CardCombo(
      type: bombType,
      cards: [...naturals, ...wilds],
      primaryRank: ranks.first,
    );
  }

  static ComboType? _bombTypeForCount(int n) {
    return switch (n) {
      4 => ComboType.bomb4,
      5 => ComboType.bomb5,
      6 => ComboType.bomb6,
      7 => ComboType.bomb7,
      8 => ComboType.bomb8,
      _ => null,
    };
  }

  static CardCombo? _detectStraightFlush(
      List<GameCard> naturals, List<GameCard> wilds, Rank level) {
    final total = naturals.length + wilds.length;
    if (total != 5) return null;

    // Jokers can't participate
    if (naturals.any((c) => c.isJoker) || wilds.any((c) => c.isJoker)) {
      return null;
    }

    // All naturals must share the same suit
    final suits = naturals.map((c) => c.suit).toSet();
    if (suits.length > 1) return null;

    // Get face values
    final faceValues = naturals.map((c) => c.rank.value).toList()..sort();

    // Try each starting position
    for (int start = 2; start <= 10; start++) {
      var wildsNeeded = 0;
      final valCounts = <int, int>{};
      for (final v in faceValues) {
        valCounts[v] = (valCounts[v] ?? 0) + 1;
      }

      var valid = true;
      var totalUsed = 0;
      for (int i = 0; i < 5; i++) {
        final rank = start + i;
        if (valCounts.containsKey(rank) && valCounts[rank]! > 0) {
          valCounts[rank] = valCounts[rank]! - 1;
          totalUsed++;
        } else {
          wildsNeeded++;
        }
      }

      if (totalUsed != naturals.length) continue;

      if (valid && wildsNeeded == wilds.length) {
        return CardCombo(
          type: ComboType.straightFlush,
          cards: [...naturals, ...wilds],
          primaryRank: start + 4,
        );
      }
    }

    return null;
  }
}
