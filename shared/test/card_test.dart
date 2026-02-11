import 'package:test/test.dart';
import 'package:guandan_shared/guandan_shared.dart';

void main() {
  group('GameCard', () {
    test('buildFullDeck creates 108 cards', () {
      final deck = buildFullDeck();
      expect(deck.length, 108);
    });

    test('buildFullDeck has 2 of each suited card', () {
      final deck = buildFullDeck();
      // 4 suits × 13 ranks × 2 decks = 104 suited + 4 jokers = 108
      final suited = deck.where((c) => !c.isJoker).toList();
      expect(suited.length, 104);

      final jokers = deck.where((c) => c.isJoker).toList();
      expect(jokers.length, 4);

      // 2 small jokers, 2 big jokers
      expect(jokers.where((c) => c.rank == Rank.smallJoker).length, 2);
      expect(jokers.where((c) => c.rank == Rank.bigJoker).length, 2);
    });

    test('key serialization roundtrip for suited cards', () {
      final card = GameCard(suit: Suit.heart, rank: Rank.five, deckIndex: 0);
      expect(card.key, 'h5-0');

      final restored = GameCard.fromKey('h5-0');
      expect(restored, card);
    });

    test('key serialization roundtrip for jokers', () {
      final sj = GameCard(rank: Rank.smallJoker, deckIndex: 1);
      expect(sj.key, 'SJ-1');
      expect(GameCard.fromKey('SJ-1'), sj);

      final bj = GameCard(rank: Rank.bigJoker, deckIndex: 0);
      expect(bj.key, 'BJ-0');
      expect(GameCard.fromKey('BJ-0'), bj);
    });

    test('key serialization for face cards', () {
      expect(
        GameCard(suit: Suit.spade, rank: Rank.ace, deckIndex: 0).key,
        's14-0',
      );
      expect(
        GameCard(suit: Suit.club, rank: Rank.king, deckIndex: 1).key,
        'c13-1',
      );
    });

    test('effectiveRank returns 20 for level card', () {
      final card = GameCard(suit: Suit.spade, rank: Rank.five, deckIndex: 0);
      expect(card.effectiveRank(Rank.five), 20);
      expect(card.effectiveRank(Rank.two), 5); // not level card
    });

    test('effectiveRank returns face value for non-level cards', () {
      final card = GameCard(suit: Suit.heart, rank: Rank.ace, deckIndex: 0);
      expect(card.effectiveRank(Rank.two), 14);
    });

    test('effectiveRank for jokers returns face value', () {
      final sj = GameCard(rank: Rank.smallJoker, deckIndex: 0);
      expect(sj.effectiveRank(Rank.two), 15);

      final bj = GameCard(rank: Rank.bigJoker, deckIndex: 0);
      expect(bj.effectiveRank(Rank.two), 16);
    });

    test('isWild returns true only for heart suit + current level', () {
      final wild = GameCard(suit: Suit.heart, rank: Rank.two, deckIndex: 0);
      expect(wild.isWild(Rank.two), true);
      expect(wild.isWild(Rank.three), false);

      final notWild =
          GameCard(suit: Suit.spade, rank: Rank.two, deckIndex: 0);
      expect(notWild.isWild(Rank.two), false);
    });

    test('isWild for jokers is always false', () {
      final sj = GameCard(rank: Rank.smallJoker, deckIndex: 0);
      expect(sj.isWild(Rank.two), false);
    });

    test('equality based on suit, rank, and deckIndex', () {
      final a = GameCard(suit: Suit.heart, rank: Rank.five, deckIndex: 0);
      final b = GameCard(suit: Suit.heart, rank: Rank.five, deckIndex: 0);
      final c = GameCard(suit: Suit.heart, rank: Rank.five, deckIndex: 1);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('JSON roundtrip', () {
      final card = GameCard(suit: Suit.diamond, rank: Rank.ten, deckIndex: 1);
      final json = card.toJson();
      final restored = GameCard.fromJson(json);
      expect(restored, card);
    });
  });

  group('Suit', () {
    test('fromInitial works for all suits', () {
      expect(Suit.fromInitial('s'), Suit.spade);
      expect(Suit.fromInitial('h'), Suit.heart);
      expect(Suit.fromInitial('d'), Suit.diamond);
      expect(Suit.fromInitial('c'), Suit.club);
    });
  });

  group('Rank', () {
    test('fromValue works', () {
      expect(Rank.fromValue(2), Rank.two);
      expect(Rank.fromValue(14), Rank.ace);
      expect(Rank.fromValue(15), Rank.smallJoker);
      expect(Rank.fromValue(16), Rank.bigJoker);
    });

    test('fromLabel works', () {
      expect(Rank.fromLabel('2'), Rank.two);
      expect(Rank.fromLabel('A'), Rank.ace);
      expect(Rank.fromLabel('J'), Rank.jack);
      expect(Rank.fromLabel('SJ'), Rank.smallJoker);
    });

    test('isJoker', () {
      expect(Rank.smallJoker.isJoker, true);
      expect(Rank.bigJoker.isJoker, true);
      expect(Rank.ace.isJoker, false);
    });
  });

  group('Player', () {
    test('teamId is seat % 2', () {
      expect(Player(id: 'a', name: 'A', seatIndex: 0).teamId, 0);
      expect(Player(id: 'b', name: 'B', seatIndex: 1).teamId, 1);
      expect(Player(id: 'c', name: 'C', seatIndex: 2).teamId, 0);
      expect(Player(id: 'd', name: 'D', seatIndex: 3).teamId, 1);
    });

    test('JSON roundtrip', () {
      final p = Player(id: 'x', name: 'Test', seatIndex: 2);
      final json = p.toJson();
      final restored = Player.fromJson(json);
      expect(restored.id, 'x');
      expect(restored.name, 'Test');
      expect(restored.seatIndex, 2);
    });
  });

  group('CardCombo', () {
    test('isBomb for bomb types', () {
      final bomb4 = CardCombo(
        type: ComboType.bomb4,
        cards: [],
        primaryRank: 5,
      );
      expect(bomb4.isBomb, true);

      final single = CardCombo(
        type: ComboType.single,
        cards: [],
        primaryRank: 5,
      );
      expect(single.isBomb, false);
    });

    test('bombPower ordering', () {
      final b4 = CardCombo(type: ComboType.bomb4, cards: [], primaryRank: 5);
      final b5 = CardCombo(type: ComboType.bomb5, cards: [], primaryRank: 5);
      final b6 = CardCombo(type: ComboType.bomb6, cards: [], primaryRank: 5);
      final sf =
          CardCombo(type: ComboType.straightFlush, cards: [], primaryRank: 6);
      final jb =
          CardCombo(type: ComboType.jokerBomb, cards: [], primaryRank: 9999);

      expect(b5.bombPower > b4.bombPower, true);
      expect(b6.bombPower > b5.bombPower, true);
      expect(sf.bombPower > b6.bombPower, true);
      expect(jb.bombPower > sf.bombPower, true);
    });

    test('beats: bomb beats non-bomb', () {
      final bomb = CardCombo(type: ComboType.bomb4, cards: [], primaryRank: 3);
      final pair = CardCombo(type: ComboType.pair, cards: [], primaryRank: 14);
      expect(bomb.beats(pair), true);
      expect(pair.beats(bomb), false);
    });

    test('beats: same type, higher rank wins', () {
      final p1 = CardCombo(type: ComboType.pair, cards: [], primaryRank: 10);
      final p2 = CardCombo(type: ComboType.pair, cards: [], primaryRank: 5);
      expect(p1.beats(p2), true);
      expect(p2.beats(p1), false);
    });

    test('beats: different non-bomb types cannot beat', () {
      final single =
          CardCombo(type: ComboType.single, cards: [], primaryRank: 14);
      final pair = CardCombo(type: ComboType.pair, cards: [], primaryRank: 3);
      expect(single.beats(pair), false);
      expect(pair.beats(single), false);
    });

    test('JSON roundtrip', () {
      final combo = CardCombo(
        type: ComboType.fullHouse,
        cards: [
          GameCard(suit: Suit.spade, rank: Rank.five, deckIndex: 0),
          GameCard(suit: Suit.heart, rank: Rank.five, deckIndex: 0),
          GameCard(suit: Suit.diamond, rank: Rank.five, deckIndex: 0),
          GameCard(suit: Suit.club, rank: Rank.three, deckIndex: 0),
          GameCard(suit: Suit.spade, rank: Rank.three, deckIndex: 1),
        ],
        primaryRank: 5,
      );
      final json = combo.toJson();
      final restored = CardCombo.fromJson(json);
      expect(restored.type, ComboType.fullHouse);
      expect(restored.primaryRank, 5);
      expect(restored.cards.length, 5);
    });
  });

  group('GameState models', () {
    test('FlipCardInfo JSON roundtrip', () {
      final info = FlipCardInfo(
        card: GameCard(suit: Suit.heart, rank: Rank.ace, deckIndex: 0),
        position: 42,
        receiverSeat: 2,
      );
      final json = info.toJson();
      final restored = FlipCardInfo.fromJson(json);
      expect(restored.position, 42);
      expect(restored.receiverSeat, 2);
      expect(restored.card, info.card);
    });

    test('RoundResult JSON roundtrip', () {
      final result = RoundResult(
        finishOrder: [0, 2, 1, 3],
        teamLevelsBefore: {0: 2, 1: 2},
        teamLevelsAfter: {0: 5, 1: 2},
        winningTeam: null,
      );
      final json = result.toJson();
      final restored = RoundResult.fromJson(json);
      expect(restored.finishOrder, [0, 2, 1, 3]);
      expect(restored.winningTeam, null);
    });
  });

  group('Protocol messages', () {
    test('ClientMsg roundtrip', () {
      final msg = CreateRoomMsg(playerName: 'Alice').toMsg();
      expect(msg.type, 'createRoom');
      expect(msg.payload['playerName'], 'Alice');

      final json = msg.toJson();
      final restored = ClientMsg.fromJson(json);
      expect(restored.type, 'createRoom');
      expect(restored.payload['playerName'], 'Alice');
    });

    test('ServerMsg roundtrip', () {
      final msg = errorMsg(message: 'test error');
      expect(msg.type, 'error');
      expect(msg.payload['message'], 'test error');

      final json = msg.toJson();
      final restored = ServerMsg.fromJson(json);
      expect(restored.type, 'error');
    });
  });
}
