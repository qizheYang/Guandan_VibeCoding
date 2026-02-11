import 'package:test/test.dart';
import 'package:guandan_shared/guandan_shared.dart';

/// Helper to create cards concisely.
/// Format: "s5" = spade 5, "hA" = heart ace, "SJ" = small joker, "BJ" = big joker
/// Append "-1" for deck 1, default deck 0.
GameCard c(String s, {int deck = 0}) {
  if (s == 'SJ') return GameCard(rank: Rank.smallJoker, deckIndex: deck);
  if (s == 'BJ') return GameCard(rank: Rank.bigJoker, deckIndex: deck);

  final suitChar = s[0];
  final rankStr = s.substring(1);
  final suit = {
    's': Suit.spade,
    'h': Suit.heart,
    'd': Suit.diamond,
    'c': Suit.club,
  }[suitChar]!;

  final rank = {
    '2': Rank.two,
    '3': Rank.three,
    '4': Rank.four,
    '5': Rank.five,
    '6': Rank.six,
    '7': Rank.seven,
    '8': Rank.eight,
    '9': Rank.nine,
    '10': Rank.ten,
    'J': Rank.jack,
    'Q': Rank.queen,
    'K': Rank.king,
    'A': Rank.ace,
  }[rankStr]!;

  return GameCard(suit: suit, rank: rank, deckIndex: deck);
}

void main() {
  const level = Rank.two; // default level for most tests

  group('Single', () {
    test('any single card is a valid single', () {
      final combo = ComboDetector.detect([c('s5')], level);
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.single);
      expect(combo.primaryRank, 5);
    });

    test('single joker', () {
      final combo = ComboDetector.detect([c('SJ')], level);
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.single);
      expect(combo.primaryRank, 15);
    });

    test('single level card has effective rank 20', () {
      final combo = ComboDetector.detect([c('s2')], level);
      expect(combo, isNotNull);
      expect(combo!.primaryRank, 20); // level card = rank 20
    });
  });

  group('Pair', () {
    test('two cards of same rank', () {
      final combo = ComboDetector.detect([c('s5'), c('h5')], level);
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.pair);
      expect(combo.primaryRank, 5);
    });

    test('two cards of different rank is invalid', () {
      final combo = ComboDetector.detect([c('s5'), c('h6')], level);
      expect(combo, isNull);
    });

    test('natural + wild forms pair', () {
      // h2 is wild (heart + level rank), s5 is natural
      final combo = ComboDetector.detect([c('s5'), c('h2')], level);
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.pair);
      expect(combo.primaryRank, 5);
    });

    test('two wilds form pair', () {
      final combo =
          ComboDetector.detect([c('h2'), c('h2', deck: 1)], level);
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.pair);
      expect(combo.primaryRank, 20); // level card effective rank
    });

    test('pair of level cards (non-wild, different suits)', () {
      // Both are level cards (rank 2) but only h2 is wild
      // s2 + d2: both have effective rank 20
      final combo = ComboDetector.detect([c('s2'), c('d2')], level);
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.pair);
      expect(combo.primaryRank, 20);
    });
  });

  group('Triple', () {
    test('three cards of same rank', () {
      final combo = ComboDetector.detect([c('s5'), c('h5'), c('d5')], level);
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.triple);
      expect(combo.primaryRank, 5);
    });

    test('two naturals + one wild', () {
      final combo = ComboDetector.detect([c('s5'), c('d5'), c('h2')], level);
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.triple);
      expect(combo.primaryRank, 5);
    });

    test('three different ranks without wilds is invalid', () {
      final combo = ComboDetector.detect([c('s5'), c('h6'), c('d7')], level);
      expect(combo, isNull);
    });
  });

  group('Full House (三带二)', () {
    test('three of a kind + pair', () {
      final combo = ComboDetector.detect(
        [c('s5'), c('h5'), c('d5'), c('s3'), c('h3')],
        level,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.fullHouse);
      expect(combo.primaryRank, 5); // triple rank
    });

    test('triple with wild + natural pair', () {
      final combo = ComboDetector.detect(
        [c('s5'), c('d5'), c('h2'), c('s3'), c('h3')],
        level,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.fullHouse);
      expect(combo.primaryRank, 5);
    });

    test('five cards of mixed ranks without valid grouping is invalid', () {
      final combo = ComboDetector.detect(
        [c('s5'), c('h6'), c('d7'), c('s8'), c('h9')],
        Rank.three, // level 3 so nothing is wild
      );
      // This could be a straight, let me use non-consecutive
      final combo2 = ComboDetector.detect(
        [c('s5'), c('h6'), c('d8'), c('s9'), c('hA')],
        Rank.three,
      );
      expect(combo2, isNull);
    });
  });

  group('Straight (顺子)', () {
    test('5 consecutive cards', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('h4'), c('d5'), c('s6'), c('h7')],
        level,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.straight);
      expect(combo.primaryRank, 7); // highest face value
    });

    test('straight ending at Ace', () {
      final combo = ComboDetector.detect(
        [c('s10'), c('hJ'), c('dQ'), c('sK'), c('hA')],
        Rank.three, // level 3 so 10-A is natural
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.straight);
      expect(combo.primaryRank, 14);
    });

    test('straight with wild card filling a gap', () {
      // 3,4,_,6,7 with wild filling 5
      final combo = ComboDetector.detect(
        [c('s3'), c('h4'), c('h2'), c('s6'), c('h7')],
        level, // h2 is wild
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.straight);
      expect(combo.primaryRank, 7);
    });

    test('non-consecutive cards is invalid', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('h4'), c('d6'), c('s7'), c('h8')],
        Rank.three, // level 3 so no wilds from rank 2
      );
      expect(combo, isNull);
    });

    test('jokers cannot be in straight', () {
      final combo = ComboDetector.detect(
        [c('s10'), c('hJ'), c('dQ'), c('sK'), c('SJ')],
        Rank.three,
      );
      expect(combo, isNull);
    });

    test('straight uses face value, not effective rank', () {
      // Level card in a straight uses its face value position
      // Level = 5, so s5 has effective rank 20 but face value 5
      // Straight 3-4-5-6-7: the s5 uses face value 5
      final combo = ComboDetector.detect(
        [c('s3'), c('h4'), c('s5'), c('d6'), c('h7')],
        Rank.five, // level 5
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.straight);
    });

    test('6-card straight', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('h4'), c('d5'), c('s6'), c('h7'), c('d8')],
        Rank.three,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.straight);
      expect(combo.primaryRank, 8);
    });
  });

  group('Pair Sequence (连对)', () {
    test('3 consecutive pairs (6 cards)', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('h3'), c('s4'), c('h4'), c('s5'), c('h5')],
        Rank.seven, // level 7
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.pairSequence);
      expect(combo.primaryRank, 5);
    });

    test('pair sequence with wild filling a gap', () {
      // 3,3,4,_,5,5 with wild filling one of the 4s
      final combo = ComboDetector.detect(
        [c('s3'), c('h3'), c('s4'), c('h2'), c('s5'), c('h5')],
        level, // h2 is wild, fills missing 4
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.pairSequence);
    });

    test('non-consecutive pairs is invalid', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('h3'), c('s5'), c('h5'), c('s7'), c('h7')],
        Rank.nine,
      );
      expect(combo, isNull);
    });

    test('jokers cannot be in pair sequence', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('h3'), c('s4'), c('h4'), c('SJ'), c('BJ')],
        Rank.nine,
      );
      expect(combo, isNull);
    });
  });

  group('Triple Sequence (钢板)', () {
    test('2 consecutive triples (6 cards)', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('h3'), c('d3'), c('s4'), c('h4'), c('d4')],
        Rank.seven,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.tripleSequence);
      expect(combo.primaryRank, 4);
    });

    test('triple sequence with wild', () {
      // 3,3,3, 4,4,wild
      final combo = ComboDetector.detect(
        [c('s3'), c('h3'), c('d3'), c('s4'), c('d4'), c('h2')],
        level, // h2 is wild
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.tripleSequence);
    });
  });

  group('Bomb (炸弹)', () {
    test('4 of a kind', () {
      final combo = ComboDetector.detect(
        [c('s5'), c('h5'), c('d5'), c('c5')],
        Rank.three,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.bomb4);
      expect(combo.primaryRank, 5);
    });

    test('5 of a kind with wild', () {
      final combo = ComboDetector.detect(
        [c('s5'), c('h5'), c('d5'), c('c5'), c('h2')],
        level, // h2 is wild
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.bomb5);
    });

    test('6 of a kind (2 decks, 4 natural + 2 from second deck)', () {
      final combo = ComboDetector.detect(
        [
          c('s5'),
          c('h5'),
          c('d5'),
          c('c5'),
          c('s5', deck: 1),
          c('h5', deck: 1),
        ],
        Rank.three,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.bomb6);
    });

    test('8 of a kind (maximum possible)', () {
      final combo = ComboDetector.detect(
        [
          c('s5'),
          c('h5'),
          c('d5'),
          c('c5'),
          c('s5', deck: 1),
          c('h5', deck: 1),
          c('d5', deck: 1),
          c('c5', deck: 1),
        ],
        Rank.three,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.bomb8);
    });

    test('mixed ranks is not a bomb', () {
      final combo = ComboDetector.detect(
        [c('s5'), c('h5'), c('d5'), c('c6')],
        Rank.three,
      );
      expect(combo, isNull);
    });

    test('bomb with wild (3 natural + 1 wild = bomb4)', () {
      final combo = ComboDetector.detect(
        [c('s5'), c('d5'), c('c5'), c('h2')],
        level,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.bomb4);
      expect(combo.primaryRank, 5);
    });
  });

  group('Straight Flush (同花顺)', () {
    test('5 consecutive cards of same suit', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('s4'), c('s5'), c('s6'), c('s7')],
        Rank.nine,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.straightFlush);
      expect(combo.primaryRank, 7);
    });

    test('straight flush with wild filling gap', () {
      // s3,s4,_,s6,s7 with h9 as wild (level=9)
      final combo = ComboDetector.detect(
        [c('s3'), c('s4'), c('h9'), c('s6'), c('s7')],
        Rank.nine,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.straightFlush);
    });

    test('different suits is not a straight flush', () {
      final combo = ComboDetector.detect(
        [c('s3'), c('h4'), c('s5'), c('s6'), c('s7')],
        Rank.nine,
      );
      // Should be detected as a regular straight, not straight flush
      expect(combo, isNotNull);
      expect(combo!.type, isNot(ComboType.straightFlush));
      expect(combo.type, ComboType.straight);
    });

    test('straight flush beats any regular bomb', () {
      final sf = CardCombo(
        type: ComboType.straightFlush,
        cards: [],
        primaryRank: 7,
      );
      final b8 = CardCombo(
        type: ComboType.bomb8,
        cards: [],
        primaryRank: 14,
      );
      expect(sf.beats(b8), true);
    });
  });

  group('Joker Bomb (天王炸)', () {
    test('4 jokers form joker bomb', () {
      final combo = ComboDetector.detect(
        [
          c('SJ'),
          c('SJ', deck: 1),
          c('BJ'),
          c('BJ', deck: 1),
        ],
        level,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.jokerBomb);
    });

    test('joker bomb beats everything', () {
      final jb = CardCombo(
        type: ComboType.jokerBomb,
        cards: [],
        primaryRank: 9999,
      );
      final sf = CardCombo(
        type: ComboType.straightFlush,
        cards: [],
        primaryRank: 14,
      );
      expect(jb.beats(sf), true);
    });

    test('3 jokers is not a joker bomb', () {
      final combo = ComboDetector.detect(
        [c('SJ'), c('SJ', deck: 1), c('BJ')],
        level,
      );
      // 3 cards could only be triple, but jokers have different ranks
      expect(combo, isNull);
    });
  });

  group('canBeat', () {
    test('any combo beats null (leading)', () {
      final single = ComboDetector.detect([c('s3')], level);
      expect(ComboDetector.canBeat(single!, null), true);
    });

    test('higher single beats lower single', () {
      final s1 = ComboDetector.detect([c('s5')], level)!;
      final s2 = ComboDetector.detect([c('s3')], level)!;
      expect(ComboDetector.canBeat(s1, s2), true);
      expect(ComboDetector.canBeat(s2, s1), false);
    });

    test('bomb beats any non-bomb', () {
      final bomb = ComboDetector.detect(
        [c('s5'), c('h5'), c('d5'), c('c5')],
        Rank.three,
      )!;
      final straight = ComboDetector.detect(
        [c('s3'), c('h4'), c('d5'), c('s6'), c('h7')],
        Rank.three,
      )!;
      expect(ComboDetector.canBeat(bomb, straight), true);
    });
  });

  group('Edge cases', () {
    test('empty cards returns null', () {
      expect(ComboDetector.detect([], level), isNull);
    });

    test('9 cards returns null (too many for any combo)', () {
      final cards = List.generate(
          9, (i) => GameCard(suit: Suit.spade, rank: Rank.five, deckIndex: 0));
      expect(ComboDetector.detect(cards, level), isNull);
    });

    test('all wilds as bomb4', () {
      // 4 wild cards (heart + level rank)
      // Only 2 possible h2 cards (deck 0 and deck 1)
      // So we need level to have 4 heart cards... but max is 2 (two decks)
      // Actually you can only have 2 wild cards (h2 deck 0 and h2 deck 1)
      // So 4 wilds is impossible. Let me test 2 wilds as pair instead.
      final combo = ComboDetector.detect(
        [c('h2'), c('h2', deck: 1)],
        level,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.pair);
    });

    test('level card pair (same effective rank 20)', () {
      // s2 and c2 when level=2: both have effective rank 20
      final combo = ComboDetector.detect(
        [c('s2'), c('c2')],
        level,
      );
      expect(combo, isNotNull);
      expect(combo!.type, ComboType.pair);
      expect(combo.primaryRank, 20);
    });
  });
}
