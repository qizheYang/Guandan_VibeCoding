import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guandan_shared/models/game_state.dart';

import '../../state/game_state_notifier.dart';
import '../widgets/card_fan.dart';
import '../widgets/play_area.dart';
import '../widgets/opponent_area.dart';
import '../widgets/partner_area.dart';
import '../widgets/scoreboard.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF0D3B0F)],
          ),
        ),
        child: SafeArea(
          child: Consumer<GameStateNotifier>(
            builder: (context, game, _) {
              if (game.gameOver) {
                return _GameOverOverlay(game: game);
              }
              if (game.phase == GamePhase.roundEnd) {
                return _RoundEndOverlay(game: game);
              }
              return _GameBoard(game: game);
            },
          ),
        ),
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  final GameStateNotifier game;
  const _GameBoard({required this.game});

  @override
  Widget build(BuildContext context) {
    final left = game.leftOpponentSeat;
    final right = game.rightOpponentSeat;
    final partner = game.partnerSeat;

    return Column(
      children: [
        const SizedBox(height: 8),
        // Scoreboard
        Scoreboard(
          teamLevels: game.teamLevels,
          myTeam: game.myTeam,
          currentLevel: game.currentLevel,
        ),
        const SizedBox(height: 8),

        // Partner (top)
        PartnerArea(
          name: game.playerNames[partner] ?? '?',
          cardCount: game.cardCounts[partner] ?? 0,
          teamId: partner % 2,
          lastPlayed: game.lastPlayedCards[partner],
          passed: game.passedThisTrick[partner] ?? false,
          finishPlace: game.finishPlaces[partner],
          isCurrentTurn: !game.isMyTurn &&
              game.currentTrick != null &&
              _isTurn(game, partner),
        ),

        // Middle row: left opponent, center play area, right opponent
        Expanded(
          child: Row(
            children: [
              // Left opponent
              Expanded(
                child: Center(
                  child: OpponentArea(
                    name: game.playerNames[left] ?? '?',
                    cardCount: game.cardCounts[left] ?? 0,
                    teamId: left % 2,
                    lastPlayed: game.lastPlayedCards[left],
                    passed: game.passedThisTrick[left] ?? false,
                    finishPlace: game.finishPlaces[left],
                    isCurrentTurn: _isTurn(game, left),
                  ),
                ),
              ),

              // Center play area - my last play
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (game.trickWinnerSeat != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${game.playerNames[game.trickWinnerSeat] ?? "?"} 赢得此轮',
                            style: const TextStyle(
                                color: Colors.amber, fontSize: 13),
                          ),
                        ),
                      PlayArea(
                        cards: game.lastPlayedCards[game.mySeatIndex],
                        playerName: game.isMyTurn ? null : '我',
                        passed:
                            game.passedThisTrick[game.mySeatIndex] ?? false,
                      ),
                      if (game.isMyTurn)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '轮到你出牌',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Right opponent
              Expanded(
                child: Center(
                  child: OpponentArea(
                    name: game.playerNames[right] ?? '?',
                    cardCount: game.cardCounts[right] ?? 0,
                    teamId: right % 2,
                    lastPlayed: game.lastPlayedCards[right],
                    passed: game.passedThisTrick[right] ?? false,
                    finishPlace: game.finishPlaces[right],
                    isCurrentTurn: _isTurn(game, right),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Error message
        if (game.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              game.errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pass button
              ElevatedButton(
                onPressed: game.canPass ? () => game.pass() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      Colors.grey.shade800.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
                child: const Text('不要', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 16),
              // Play button
              ElevatedButton(
                onPressed: game.canPlay
                    ? () {
                        final err = game.playSelected();
                        if (err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8F00),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      Colors.orange.shade900.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
                child: const Text('出牌', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 16),
              // Clear selection
              IconButton(
                onPressed: game.selectedIndices.isNotEmpty
                    ? () => game.clearSelection()
                    : null,
                icon: const Icon(Icons.clear_all),
                color: Colors.white54,
                tooltip: '清除选择',
              ),
            ],
          ),
        ),

        // My hand
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: CardFan(
            cards: game.myHand,
            selectedIndices: game.selectedIndices,
            currentLevel: game.currentLevel,
            onCardTap: game.isMyTurn
                ? (index) => game.toggleCardSelection(index)
                : null,
          ),
        ),
      ],
    );
  }

  bool _isTurn(GameStateNotifier game, int seat) {
    // Simple heuristic: not perfectly accurate without server telling us
    // whose turn it is, but shows the turn indicator
    return false;
  }
}

class _RoundEndOverlay extends StatelessWidget {
  final GameStateNotifier game;
  const _RoundEndOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    final result = game.roundResult;
    if (result == null) return const SizedBox.shrink();

    final myTeam = game.myTeam;
    final myBefore = result.teamLevelsBefore[myTeam] ?? 2;
    final myAfter = result.teamLevelsAfter[myTeam] ?? 2;
    final opBefore = result.teamLevelsBefore[1 - myTeam] ?? 2;
    final opAfter = result.teamLevelsAfter[1 - myTeam] ?? 2;
    final won = myAfter > myBefore;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2B1B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: won ? Colors.amber : Colors.white24,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won ? '本轮胜利!' : '本轮失败',
              style: TextStyle(
                color: won ? Colors.amber : Colors.white70,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '我方: $myBefore → $myAfter',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '对方: $opBefore → $opAfter',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 24),
            const Text(
              '等待下一局...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final GameStateNotifier game;
  const _GameOverOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    final won = game.winningTeam == game.myTeam;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2B1B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: won ? Colors.amber : Colors.redAccent,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              color: won ? Colors.amber : Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              won ? '恭喜获胜!' : '游戏结束',
              style: TextStyle(
                color: won ? Colors.amber : Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('返回大厅',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
