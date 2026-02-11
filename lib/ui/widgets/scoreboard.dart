import 'package:flutter/material.dart';
import 'package:guandan_shared/models/card.dart';

class Scoreboard extends StatelessWidget {
  final Map<int, int> teamLevels;
  final int myTeam;
  final Rank? currentLevel;

  const Scoreboard({
    super.key,
    required this.teamLevels,
    required this.myTeam,
    this.currentLevel,
  });

  String _levelLabel(int value) {
    return switch (value) {
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      14 => 'A',
      _ => value.toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final myLevel = teamLevels[myTeam] ?? 2;
    final opLevel = teamLevels[1 - myTeam] ?? 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _teamChip('我方', _levelLabel(myLevel), const Color(0xFF1565C0)),
          if (currentLevel != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Text(
                '打${_levelLabel(currentLevel!.value)}',
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(width: 12),
          _teamChip('对方', _levelLabel(opLevel), const Color(0xFFD84315)),
        ],
      ),
    );
  }

  Widget _teamChip(String label, String level, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(width: 4),
        Text(level,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
