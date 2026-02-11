enum Suit {
  spade('♠', 's'),
  heart('♥', 'h'),
  diamond('♦', 'd'),
  club('♣', 'c');

  final String symbol;
  final String initial;
  const Suit(this.symbol, this.initial);

  static Suit fromInitial(String i) =>
      Suit.values.firstWhere((s) => s.initial == i);
}

enum Rank {
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A'),
  smallJoker(15, 'SJ'),
  bigJoker(16, 'BJ');

  final int value;
  final String label;
  const Rank(this.value, this.label);

  static Rank fromValue(int v) =>
      Rank.values.firstWhere((r) => r.value == v);

  static Rank fromLabel(String l) =>
      Rank.values.firstWhere((r) => r.label == l);

  bool get isJoker => this == smallJoker || this == bigJoker;
}

class GameCard {
  final Suit? suit;
  final Rank rank;
  final int deckIndex; // 0 or 1

  const GameCard({this.suit, required this.rank, this.deckIndex = 0});

  bool get isJoker => rank.isJoker;

  /// Effective rank for comparison given current level.
  /// Big Joker (99) > Small Joker (98) > Level card (20) > A(14) > ... > 2(2)
  int effectiveRank(Rank currentLevel) {
    if (rank == Rank.bigJoker) return 99;
    if (rank == Rank.smallJoker) return 98;
    if (rank == currentLevel) return 20;
    return rank.value;
  }

  /// Whether this card is wild (红心级牌 / 逢人配).
  bool isWild(Rank currentLevel) =>
      suit == Suit.heart && rank == currentLevel;

  /// Serialization key: "h5-0", "s14-1", "SJ-0", "BJ-1"
  String get key {
    if (isJoker) return '${rank.label}-$deckIndex';
    return '${suit!.initial}${rank.value}-$deckIndex';
  }

  factory GameCard.fromKey(String key) {
    final parts = key.split('-');
    final deckIdx = int.parse(parts[1]);
    final body = parts[0];

    if (body == 'SJ') {
      return GameCard(rank: Rank.smallJoker, deckIndex: deckIdx);
    }
    if (body == 'BJ') {
      return GameCard(rank: Rank.bigJoker, deckIndex: deckIdx);
    }

    final suitInitial = body[0];
    final rankValue = int.parse(body.substring(1));
    return GameCard(
      suit: Suit.fromInitial(suitInitial),
      rank: Rank.fromValue(rankValue),
      deckIndex: deckIdx,
    );
  }

  /// Asset path for the card image SVG.
  /// Files: {rank}{SuitInitial}.svg, e.g. "AS.svg", "10H.svg", "Joker1.svg"
  String get assetPath {
    if (rank == Rank.smallJoker) return 'assets/cards/Joker1.svg';
    if (rank == Rank.bigJoker) return 'assets/cards/Joker2.svg';
    final suitChar = switch (suit!) {
      Suit.spade => 'S',
      Suit.heart => 'H',
      Suit.diamond => 'D',
      Suit.club => 'C',
    };
    final rankStr = switch (rank) {
      Rank.ace => 'A',
      Rank.king => 'K',
      Rank.queen => 'Q',
      Rank.jack => 'J',
      _ => rank.value.toString(),
    };
    return 'assets/cards/$rankStr$suitChar.svg';
  }

  static const String backAssetPath = 'assets/cards/back.svg';

  Map<String, dynamic> toJson() => {'key': key};
  factory GameCard.fromJson(Map<String, dynamic> j) =>
      GameCard.fromKey(j['key'] as String);

  @override
  bool operator ==(Object other) =>
      other is GameCard &&
      other.suit == suit &&
      other.rank == rank &&
      other.deckIndex == deckIndex;

  @override
  int get hashCode => Object.hash(suit, rank, deckIndex);

  @override
  String toString() {
    if (isJoker) return rank.label;
    return '${suit!.symbol}${rank.label}';
  }
}

/// Build a full deck of 108 cards (2 standard decks with jokers).
List<GameCard> buildFullDeck() {
  final cards = <GameCard>[];
  for (int deck = 0; deck < 2; deck++) {
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        if (rank.isJoker) continue;
        cards.add(GameCard(suit: suit, rank: rank, deckIndex: deck));
      }
    }
    cards.add(GameCard(rank: Rank.smallJoker, deckIndex: deck));
    cards.add(GameCard(rank: Rank.bigJoker, deckIndex: deck));
  }
  assert(cards.length == 108);
  return cards;
}
