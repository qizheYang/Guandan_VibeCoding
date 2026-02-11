import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:guandan_shared/guandan_shared.dart';
import 'package:guandan_server/room_manager.dart';
import 'package:guandan_server/client_connection.dart';

/// Test harness: runs a real WebSocket server + 4 WebSocket clients.
void main() {
  late HttpServer server;
  late RoomManager roomManager;
  late int port;

  setUp(() async {
    roomManager = RoomManager();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server.port;

    // Handle WebSocket upgrades
    server.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        final conn = ClientConnection(socket, roomManager);
        conn.listen();
      } else {
        request.response.statusCode = 200;
        await request.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  /// Helper: connect a WebSocket client and return a message stream + sender.
  Future<_TestClient> connectClient(String name) async {
    final ws = await WebSocket.connect('ws://localhost:$port');
    return _TestClient(ws, name);
  }

  test('turn progresses after each play', () async {
    // Connect 4 players
    final clients = <_TestClient>[];
    for (final name in ['Alice', 'Bob', 'Carol', 'Dave']) {
      clients.add(await connectClient(name));
    }

    // Player 0 creates room
    clients[0].send({'type': 'createRoom', 'payload': {'playerName': 'Alice'}});
    final roomCreated = await clients[0].waitFor('roomCreated');
    final roomCode = roomCreated['roomCode'] as String;
    expect(roomCode.length, 4);

    // Players 1-3 join
    for (int i = 1; i < 4; i++) {
      clients[i].send({
        'type': 'joinRoom',
        'payload': {'roomCode': roomCode, 'playerName': clients[i].name},
      });
      await clients[i].waitFor('roomJoined');
    }

    // Drain seatsAssigned messages (seats get shuffled when 4th joins)
    for (final c in clients) {
      await c.waitFor('seatsAssigned');
    }

    // Build a map: playerId → client & seatIndex
    final seatMap = <int, _TestClient>{};
    for (final c in clients) {
      seatMap[c.seatIndex!] = c;
    }

    // All ready
    for (final c in clients) {
      c.send({'type': 'ready', 'payload': {}});
    }

    // Wait for gameStart on all clients
    final gameStarts = <int, Map<String, dynamic>>{};
    for (final c in clients) {
      final gs = await c.waitFor('gameStart');
      gameStarts[c.seatIndex!] = gs;
    }

    // The first player should get yourTurn
    // Find which client is first player
    final firstPlayerSeat = gameStarts.values.first['firstPlayer'] as int;
    final firstClient = seatMap[firstPlayerSeat]!;

    // First player may have already received yourTurn or it arrives now
    final yourTurn1 = await firstClient.waitFor('yourTurn');
    expect(yourTurn1, isNotNull);
    print('First player seat=$firstPlayerSeat got yourTurn');

    // Parse first player's hand
    final handKeys =
        (gameStarts[firstPlayerSeat]!['yourHand'] as List).cast<String>();
    final hand = handKeys.map(GameCard.fromKey).toList();
    final level = Rank.fromValue(gameStarts[firstPlayerSeat]!['currentLevel'] as int);

    // Play a single card (first card in hand)
    final cardToPlay = hand.first;
    firstClient.send({
      'type': 'playCards',
      'payload': {
        'cardKeys': [cardToPlay.key]
      },
    });

    // All clients should receive cardsPlayed
    for (final c in clients) {
      final cp = await c.waitFor('cardsPlayed');
      expect(cp['seatIndex'], firstPlayerSeat);
      print('  ${c.name} (seat ${c.seatIndex}) received cardsPlayed');
    }

    // The NEXT player should receive yourTurn
    final nextSeat = _nextActiveSeat(firstPlayerSeat);
    final nextClient = seatMap[nextSeat]!;
    final yourTurn2 = await nextClient.waitFor('yourTurn');
    expect(yourTurn2, isNotNull);
    print('Next player seat=$nextSeat (${nextClient.name}) got yourTurn');

    // Next player plays a higher card or passes
    final nextHandKeys =
        (gameStarts[nextSeat]!['yourHand'] as List).cast<String>();
    final nextHand = nextHandKeys.map(GameCard.fromKey).toList();
    nextHand.sort((a, b) => a.effectiveRank(level).compareTo(b.effectiveRank(level)));

    final currentTrick = yourTurn2['currentTrick'] != null
        ? CardCombo.fromJson(yourTurn2['currentTrick'] as Map<String, dynamic>)
        : null;

    // Find a card that beats the current trick
    GameCard? beatCard;
    if (currentTrick != null) {
      for (final card in nextHand.reversed) {
        final combo = ComboDetector.detect([card], level);
        if (combo != null && ComboDetector.canBeat(combo, currentTrick)) {
          beatCard = card;
          break;
        }
      }
    }

    if (beatCard != null) {
      nextClient.send({
        'type': 'playCards',
        'payload': {
          'cardKeys': [beatCard.key]
        },
      });

      // All should receive cardsPlayed
      for (final c in clients) {
        final cp = await c.waitFor('cardsPlayed');
        expect(cp['seatIndex'], nextSeat);
      }

      // Third player should get yourTurn
      final thirdSeat = _nextActiveSeat(nextSeat);
      final thirdClient = seatMap[thirdSeat]!;
      final yourTurn3 = await thirdClient.waitFor('yourTurn');
      expect(yourTurn3, isNotNull);
      print('Third player seat=$thirdSeat (${thirdClient.name}) got yourTurn');
    } else {
      // Pass instead
      nextClient.send({'type': 'pass', 'payload': {}});

      for (final c in clients) {
        final pp = await c.waitFor('playerPassed');
        expect(pp['seatIndex'], nextSeat);
      }

      final thirdSeat = _nextActiveSeat(nextSeat);
      final thirdClient = seatMap[thirdSeat]!;
      final yourTurn3 = await thirdClient.waitFor('yourTurn');
      expect(yourTurn3, isNotNull);
      print('Third player seat=$thirdSeat (${thirdClient.name}) got yourTurn (after pass)');
    }

    print('Turn progression verified across 3 players!');

    // Cleanup
    for (final c in clients) {
      await c.close();
    }
  }, timeout: Timeout(Duration(seconds: 30)));

  test('full round with all players taking turns', () async {
    final clients = <_TestClient>[];
    for (final name in ['P0', 'P1', 'P2', 'P3']) {
      clients.add(await connectClient(name));
    }

    // Create and join room
    clients[0].send({'type': 'createRoom', 'payload': {'playerName': 'P0'}});
    final rc = await clients[0].waitFor('roomCreated');
    final code = rc['roomCode'] as String;

    for (int i = 1; i < 4; i++) {
      clients[i].send({
        'type': 'joinRoom',
        'payload': {'roomCode': code, 'playerName': 'P${i}'},
      });
      await clients[i].waitFor('roomJoined');
    }

    // Drain seatsAssigned
    for (final c in clients) {
      await c.waitFor('seatsAssigned');
    }

    final seatMap = <int, _TestClient>{};
    for (final c in clients) {
      seatMap[c.seatIndex!] = c;
    }

    // All ready
    for (final c in clients) {
      c.send({'type': 'ready', 'payload': {}});
    }

    // Wait for gameStart
    final hands = <int, List<GameCard>>{};
    int firstPlayer = -1;
    late Rank level;
    for (final c in clients) {
      final gs = await c.waitFor('gameStart');
      final seat = c.seatIndex!;
      final hk = (gs['yourHand'] as List).cast<String>();
      hands[seat] = hk.map(GameCard.fromKey).toList();
      firstPlayer = gs['firstPlayer'] as int;
      level = Rank.fromValue(gs['currentLevel'] as int);
    }

    // Drain the first yourTurn
    await seatMap[firstPlayer]!.waitFor('yourTurn');

    int turnCount = 0;
    int currentSeat = firstPlayer;

    // Play 20 turns (mix of plays and passes) to verify turn progresses
    while (turnCount < 20) {
      final client = seatMap[currentSeat]!;
      final hand = hands[currentSeat]!;

      if (hand.isEmpty) break;

      // Try to play lowest single
      bool played = false;

      if (turnCount == 0 || client.lastTrick == null) {
        // Leading: play lowest card
        final card = hand.first;
        client.send({
          'type': 'playCards',
          'payload': {
            'cardKeys': [card.key]
          },
        });

        // Wait for cardsPlayed on all
        for (final c in clients) {
          await c.waitFor('cardsPlayed');
        }
        hand.remove(card);
        played = true;
      } else {
        // Following: try to beat or pass
        final trick = client.lastTrick!;
        GameCard? beatCard;
        for (final card in hand.reversed) {
          final combo = ComboDetector.detect([card], level);
          if (combo != null && ComboDetector.canBeat(combo, trick)) {
            beatCard = card;
            break;
          }
        }

        if (beatCard != null) {
          client.send({
            'type': 'playCards',
            'payload': {
              'cardKeys': [beatCard.key]
            },
          });
          for (final c in clients) {
            await c.waitFor('cardsPlayed');
          }
          hand.remove(beatCard);
          played = true;
        } else {
          // Pass
          client.send({'type': 'pass', 'payload': {}});
          for (final c in clients) {
            final msg = await c.waitForAny(['playerPassed', 'trickWon']);
            // Drain trickWon if it comes after playerPassed
            if (msg.$1 == 'playerPassed') {
              // There might be a trickWon following
            }
          }
        }
      }

      turnCount++;

      // Wait for next yourTurn (might go to different player if trick was won)
      // Find who gets the next turn
      bool gotTurn = false;
      for (final c in clients) {
        final turnMsg = c.checkPending('yourTurn');
        if (turnMsg != null) {
          currentSeat = c.seatIndex!;
          c.lastTrick = turnMsg['currentTrick'] != null
              ? CardCombo.fromJson(turnMsg['currentTrick'] as Map<String, dynamic>)
              : null;
          gotTurn = true;
          break;
        }
      }

      if (!gotTurn) {
        // Wait a bit then check again
        for (final c in clients) {
          try {
            final turnMsg = await c.waitFor('yourTurn',
                timeout: Duration(milliseconds: 500));
            currentSeat = c.seatIndex!;
            c.lastTrick = turnMsg['currentTrick'] != null
                ? CardCombo.fromJson(
                    turnMsg['currentTrick'] as Map<String, dynamic>)
                : null;
            gotTurn = true;
            break;
          } catch (_) {
            continue;
          }
        }
      }

      if (!gotTurn) {
        fail('No player received yourTurn after turn $turnCount');
      }

      print('Turn $turnCount: seat $currentSeat playing');
    }

    print('Successfully completed $turnCount turns!');

    for (final c in clients) {
      await c.close();
    }
  }, timeout: Timeout(Duration(seconds: 30)));
}

int _nextActiveSeat(int current) => (current + 1) % 4;

class _TestClient {
  final WebSocket ws;
  final String name;
  int? seatIndex;
  String? playerId;
  CardCombo? lastTrick;
  final List<Map<String, dynamic>> _pending = [];
  final _completer = <Completer<Map<String, dynamic>>>[];
  final _typeFilter = <String>[];

  _TestClient(this.ws, this.name) {
    ws.listen((data) {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final payload = json['payload'] as Map<String, dynamic>? ?? {};
      final type = json['type'] as String;

      // Track seat assignment
      if (type == 'roomCreated' || type == 'roomJoined') {
        seatIndex = payload['seatIndex'] as int;
        playerId = payload['playerId'] as String;
      }
      if (type == 'seatsAssigned') {
        final players = (payload['players'] as List);
        for (final p in players) {
          final pm = p as Map<String, dynamic>;
          if (pm['id'] == playerId) {
            seatIndex = pm['seatIndex'] as int;
          }
        }
      }

      // Check if any completer is waiting for this type
      for (int i = 0; i < _completer.length; i++) {
        if (_typeFilter[i] == type || _typeFilter[i] == '*') {
          final c = _completer.removeAt(i);
          _typeFilter.removeAt(i);
          c.complete(payload..['_type'] = type);
          return;
        }
      }

      // Buffer it
      _pending.add(payload..['_type'] = type);
    });
  }

  void send(Map<String, dynamic> msg) {
    ws.add(jsonEncode(msg));
  }

  /// Wait for a specific message type. Returns payload.
  Future<Map<String, dynamic>> waitFor(String type,
      {Duration timeout = const Duration(seconds: 5)}) async {
    // Check pending first
    for (int i = 0; i < _pending.length; i++) {
      if (_pending[i]['_type'] == type) {
        return _pending.removeAt(i);
      }
    }

    // Wait for it
    final c = Completer<Map<String, dynamic>>();
    _completer.add(c);
    _typeFilter.add(type);
    return c.future.timeout(timeout, onTimeout: () {
      // Remove the completer
      final idx = _completer.indexOf(c);
      if (idx >= 0) {
        _completer.removeAt(idx);
        _typeFilter.removeAt(idx);
      }
      throw TimeoutException(
          '$name (seat $seatIndex): Timed out waiting for "$type". Pending: ${_pending.map((p) => p['_type']).toList()}');
    });
  }

  Future<(String, Map<String, dynamic>)> waitForAny(List<String> types,
      {Duration timeout = const Duration(seconds: 5)}) async {
    for (int i = 0; i < _pending.length; i++) {
      if (types.contains(_pending[i]['_type'])) {
        final msg = _pending.removeAt(i);
        return (msg['_type'] as String, msg);
      }
    }
    final c = Completer<Map<String, dynamic>>();
    _completer.add(c);
    _typeFilter.add('*');
    final result = await c.future.timeout(timeout);
    return (result['_type'] as String, result);
  }

  Map<String, dynamic>? checkPending(String type) {
    for (int i = 0; i < _pending.length; i++) {
      if (_pending[i]['_type'] == type) {
        return _pending.removeAt(i);
      }
    }
    return null;
  }

  Future<void> close() async {
    await ws.close();
  }
}
