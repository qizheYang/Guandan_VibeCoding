import 'package:flutter/material.dart';
import 'package:guandan_shared/models/card.dart';

import 'play_area.dart';

/// Displays the partner (top of the board).
class PartnerArea extends StatelessWidget {
  final String name;
  final int cardCount;
  final int teamId;
  final List<GameCard>? lastPlayed;
  final bool passed;
  final int? finishPlace;
  final bool isCurrentTurn;

  const PartnerArea({
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrentTurn
                ? Colors.amber.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentTurn
                  ? Colors.amber.withValues(alpha: 0.6)
                  : teamColor.withValues(alpha: 0.3),
              width: isCurrentTurn ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, color: teamColor, size: 18),
              const SizedBox(width: 6),
              Text(name,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(width: 12),
              if (finishPlace != null)
                Text('第$finishPlace名',
                    style:
                        const TextStyle(color: Colors.amber, fontSize: 13))
              else
                Text('$cardCount 张',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        PlayArea(
          cards: lastPlayed,
          passed: passed,
          finishPlace: finishPlace,
        ),
      ],
    );
  }
}
