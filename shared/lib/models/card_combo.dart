import 'card.dart';

enum ComboType {
  single,
  pair,
  triple,
  fullHouse,     // 三带二
  straight,      // 顺子 (5 consecutive)
  pairSequence,  // 连对 (3+ consecutive pairs)
  tripleSequence,// 钢板 (2+ consecutive triples)
  bomb4,
  bomb5,
  bomb6,
  bomb7,
  bomb8,
  straightFlush, // 同花顺
  jokerBomb,     // 天王炸 (4 jokers)
}

class CardCombo {
  final ComboType type;
  final List<GameCard> cards;
  /// Primary rank used for same-type comparison.
  final int primaryRank;

  const CardCombo({
    required this.type,
    required this.cards,
    required this.primaryRank,
  });

  bool get isBomb => type.index >= ComboType.bomb4.index;

  int get length => cards.length;

  /// Bomb power for cross-type bomb comparison.
  int get bombPower {
    return switch (type) {
      ComboType.bomb4 => 100 + primaryRank,
      ComboType.bomb5 => 200 + primaryRank,
      ComboType.bomb6 => 300 + primaryRank,
      ComboType.bomb7 => 400 + primaryRank,
      ComboType.bomb8 => 500 + primaryRank,
      ComboType.straightFlush => 600 + primaryRank,
      ComboType.jokerBomb => 9999,
      _ => 0,
    };
  }

  /// Whether this combo can beat [other].
  bool beats(CardCombo other) {
    // Bomb beats non-bomb
    if (isBomb && !other.isBomb) return true;
    if (!isBomb && other.isBomb) return false;

    // Both bombs: compare bomb power
    if (isBomb && other.isBomb) {
      return bombPower > other.bombPower;
    }

    // Both non-bomb: must be same type and same length
    if (type != other.type) return false;
    if (length != other.length) return false;

    return primaryRank > other.primaryRank;
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'cards': cards.map((c) => c.toJson()).toList(),
    'primaryRank': primaryRank,
  };

  factory CardCombo.fromJson(Map<String, dynamic> j) => CardCombo(
    type: ComboType.values.byName(j['type'] as String),
    cards: (j['cards'] as List).map((c) =>
        GameCard.fromJson(c as Map<String, dynamic>)).toList(),
    primaryRank: j['primaryRank'] as int,
  );
}
