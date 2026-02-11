import 'dart:math';

import 'package:guandan_shared/guandan_shared.dart';

import 'client_connection.dart';

class GameSession {
  final String roomCode;
  final List<ClientConnection?> seats = List.filled(4, null);
  final List<String?> playerIds = List.filled(4, null);
  final List<String> playerNames = List.filled(4, '');
  final List<bool> ready = List.filled(4, false);
  GameEngine? engine;
  bool gameInProgress = false;
  int roundNumber = 0;

  GameSession(this.roomCode);

  bool get isEmpty => seats.every((s) => s == null);

  // ── Player Management ──

  void addPlayer(ClientConnection conn, String name) {
    final seat = seats.indexOf(null);
    if (seat == -1) {
      conn.send(errorMsg(message: 'Room is full'));
      return;
    }

    final id = _generateId();
    conn.playerId = id;
    conn.playerName = name;
    conn.roomCode = roomCode;
    conn.seatIndex = seat;

    seats[seat] = conn;
    playerIds[seat] = id;
    playerNames[seat] = name;

    // Send room info to the joining player
    conn.send(roomCreatedMsg(
      roomCode: roomCode,
      seatIndex: seat,
      playerId: id,
    ));

    // Send current players list
    final players = <Player>[];
    for (int i = 0; i < 4; i++) {
      if (playerIds[i] != null) {
        players.add(Player(
          id: playerIds[i]!,
          name: playerNames[i],
          seatIndex: i,
        ));
      }
    }
    conn.send(roomJoinedMsg(
      roomCode: roomCode,
      seatIndex: seat,
      playerId: id,
      players: players,
    ));

    // Broadcast to others
    final newPlayer = Player(id: id, name: name, seatIndex: seat);
    _broadcastExcept(seat, playerJoinedMsg(player: newPlayer));

    // Also send ready status of existing players
    for (int i = 0; i < 4; i++) {
      if (i != seat && ready[i] && playerIds[i] != null) {
        conn.send(playerReadyMsg(playerId: playerIds[i]!));
      }
    }

    // When all 4 players are present, randomly shuffle seats
    if (_allPresent()) {
      _shuffleSeats();
    }
  }

  void removePlayer(ClientConnection conn) {
    final seat = conn.seatIndex;
    if (seat == null || seat < 0 || seat >= 4) return;

    final id = playerIds[seat];
    seats[seat] = null;
    playerIds[seat] = null;
    playerNames[seat] = '';
    ready[seat] = false;

    if (id != null) {
      _broadcast(playerLeftMsg(playerId: id, seatIndex: seat));
    }

    // If game is in progress and a player leaves, end the game
    if (gameInProgress) {
      gameInProgress = false;
      engine = null;
      _broadcast(errorMsg(message: 'A player left. Game ended.'));
      // Reset ready status
      for (int i = 0; i < 4; i++) {
        ready[i] = false;
      }
    }
  }

  // ── Ready ──

  void playerReady(ClientConnection conn) {
    final seat = conn.seatIndex;
    if (seat == null) return;

    ready[seat] = true;
    _broadcast(playerReadyMsg(playerId: conn.playerId!));

    // Check if all 4 are present and ready
    if (_allPresent() && ready.every((r) => r)) {
      _startGame();
    }
  }

  // ── Game Start ──

  void _startGame() {
    roundNumber++;
    engine = GameEngine(
      teamLevels: roundNumber == 1
          ? {0: Rank.two, 1: Rank.two}
          : engine?.teamLevels ?? {0: Rank.two, 1: Rank.two},
    );
    engine!.deal();
    gameInProgress = true;

    // Send each player their hand and game info
    for (int i = 0; i < 4; i++) {
      final infos = _buildPlayerInfos();
      seats[i]?.send(gameStartMsg(
        yourHand: engine!.hands[i],
        currentLevelValue: engine!.currentLevel.value,
        teamLevels: engine!.teamLevels.map((k, v) => MapEntry(k, v.value)),
        flipCard: engine!.flipCard!,
        firstPlayer: engine!.currentPlayer,
        playerInfos: infos,
      ));
    }

    // Notify the first player it's their turn
    _sendTurnNotification();
  }

  // ── Play Cards ──

  void playCards(ClientConnection conn, List<String> cardKeys) {
    if (engine == null || !gameInProgress) {
      conn.send(errorMsg(message: 'No game in progress'));
      return;
    }

    final seat = conn.seatIndex;
    if (seat == null) return;

    final cards = cardKeys.map(GameCard.fromKey).toList();

    try {
      final combo = engine!.playCards(seat, cards);
      print('[playCards] seat=$seat played ${combo.type.name} (${cards.length} cards), next=${engine!.currentPlayer}');

      // Broadcast the play (include nextPlayer so all clients know whose turn it is)
      _broadcast(cardsPlayedMsg(
        playerId: conn.playerId!,
        seatIndex: seat,
        cards: cards,
        comboType: combo.type.name,
        cardCount: engine!.hands[seat].length,
        nextPlayer: engine!.currentPlayer,
      ));

      // Check if player finished
      if (engine!.hands[seat].isEmpty) {
        _broadcast(playerFinishedMsg(
          playerId: conn.playerId!,
          seatIndex: seat,
          place: engine!.finishOrder.length,
        ));
      }

      // Check if round ended
      if (engine!.phase == GamePhase.roundEnd) {
        final result = engine!.calculateRoundResult();
        _broadcast(roundEndMsg(result: result));

        if (result.winningTeam != null) {
          _broadcast(gameOverMsg(winningTeam: result.winningTeam!));
          gameInProgress = false;
        } else {
          // Reset ready for next round
          gameInProgress = false;
          for (int i = 0; i < 4; i++) {
            ready[i] = false;
          }
        }
        return;
      }

      // Next player's turn
      try {
        _sendTurnNotification();
        print('[playCards] yourTurn sent to seat ${engine!.currentPlayer}');
      } catch (e2) {
        print('[playCards] ERROR sending turn notification: $e2');
        // Still try to send turn via a simpler message
        final current = engine!.currentPlayer;
        seats[current]?.send(yourTurnMsg(
          currentTrick: null,
          consecutivePasses: engine!.consecutivePasses,
        ));
      }
    } catch (e, st) {
      print('[playCards] ERROR: $e\n$st');
      conn.send(errorMsg(message: '$e'));
    }
  }

  // ── Pass ──

  void playerPass(ClientConnection conn) {
    if (engine == null || !gameInProgress) {
      conn.send(errorMsg(message: 'No game in progress'));
      return;
    }

    final seat = conn.seatIndex;
    if (seat == null) return;

    try {
      engine!.pass(seat);

      _broadcast(playerPassedMsg(
        playerId: conn.playerId!,
        seatIndex: seat,
        nextPlayer: engine!.currentPlayer,
      ));

      // Check if trick was won (currentTrick became null)
      if (engine!.currentTrick == null) {
        _broadcast(trickWonMsg(
          winnerId: playerIds[engine!.currentPlayer] ?? '',
          winnerSeat: engine!.currentPlayer,
          nextPlayer: engine!.currentPlayer,
        ));
      }

      _sendTurnNotification();
    } catch (e) {
      conn.send(errorMsg(message: '$e'));
    }
  }

  // ── Tribute (placeholder) ──

  void tributeGive(ClientConnection conn, String cardKey) {
    // TODO: implement tribute phase
    conn.send(errorMsg(message: 'Tribute not yet implemented'));
  }

  void tributeReturn(ClientConnection conn, String cardKey) {
    // TODO: implement tribute phase
    conn.send(errorMsg(message: 'Tribute not yet implemented'));
  }

  // ── Helpers ──

  void _sendTurnNotification() {
    final current = engine!.currentPlayer;
    seats[current]?.send(yourTurnMsg(
      currentTrick: engine!.currentTrick,
      consecutivePasses: engine!.consecutivePasses,
    ));
  }

  List<PlayerPublicInfo> _buildPlayerInfos() {
    return List.generate(4, (i) => PlayerPublicInfo(
      playerId: playerIds[i] ?? '',
      name: playerNames[i],
      seatIndex: i,
      cardCount: engine?.hands[i].length ?? 0,
      finishOrder: engine != null && engine!.finishOrder.contains(i)
          ? engine!.finishOrder.indexOf(i) + 1
          : null,
    ));
  }

  void _shuffleSeats() {
    final rng = Random();
    // Collect current players
    final conns = <ClientConnection>[];
    final ids = <String>[];
    final names = <String>[];
    for (int i = 0; i < 4; i++) {
      conns.add(seats[i]!);
      ids.add(playerIds[i]!);
      names.add(playerNames[i]);
    }

    // Generate a random permutation of [0,1,2,3]
    final newOrder = [0, 1, 2, 3]..shuffle(rng);

    // Reassign based on shuffle
    for (int i = 0; i < 4; i++) {
      final newSeat = newOrder[i];
      seats[newSeat] = conns[i];
      playerIds[newSeat] = ids[i];
      playerNames[newSeat] = names[i];
      conns[i].seatIndex = newSeat;
    }

    // Build updated player list and broadcast to all
    final players = <Player>[];
    for (int i = 0; i < 4; i++) {
      players.add(Player(
        id: playerIds[i]!,
        name: playerNames[i],
        seatIndex: i,
      ));
    }

    // Send each player the new assignments with their personal seat index
    for (int i = 0; i < 4; i++) {
      seats[i]!.send(seatsAssignedMsg(players: players));
    }
  }

  bool _allPresent() => seats.every((s) => s != null);

  void _broadcast(ServerMsg msg) {
    for (final s in seats) {
      s?.send(msg);
    }
  }

  void _broadcastExcept(int seat, ServerMsg msg) {
    for (int i = 0; i < 4; i++) {
      if (i != seat) seats[i]?.send(msg);
    }
  }

  String _generateId() {
    final rng = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
