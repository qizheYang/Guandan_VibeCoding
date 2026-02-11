import 'package:flutter/material.dart';
import 'package:guandan_shared/models/card.dart';

import 'play_area.dart';

/// Displays an opponent (left or right side of the board).
class OpponentArea extends StatelessWidget {
  final String name;
  final int cardCount;
  final int teamId;
  final List<GameCard>? lastPlayed;
  final bool passed;
  final int? finishPlace;
  final bool isCurrentTurn;

  const OpponentArea({
    super.key,
    required this.name,
    required this.cardCount,
    required this.teamId,
    this.lastPlayed,
    this.passed = false,
    this.finishPlace,
    this.isCurrentTurn = false,
  });

  @override
  Widget build(BuildContext context) {
    final teamColor =
        teamId == 0 ? const Color(0xFF1565C0) : const Color(0xFFD84315);

    return SizedBox(
      width: 140,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name + card count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrentTurn
                  ? Colors.amber.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrentTurn
                    ? Colors.amber.withValues(alpha: 0.6)
                    : teamColor.withValues(alpha: 0.3),
                width: isCurrentTurn ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: teamColor, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (finishPlace != null)
                  Text('第$finishPlace名',
                      style:
                          const TextStyle(color: Colors.amber, fontSize: 12))
                else
                  Text('$cardCount 张牌',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Last played cards
          PlayArea(
            cards: lastPlayed,
            passed: passed,
            finishPlace: finishPlace,
          ),
        ],
      ),
    );
  }
}
