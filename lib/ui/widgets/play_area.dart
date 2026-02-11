import 'package:flutter/material.dart';
import 'package:guandan_shared/models/card.dart';

import 'card_widget.dart';

/// Displays cards played in the center of the table.
class PlayArea extends StatelessWidget {
  final List<GameCard>? cards;
  final String? playerName;
  final bool passed;
  final int? finishPlace;

  const PlayArea({
    super.key,
    this.cards,
    this.playerName,
    this.passed = false,
    this.finishPlace,
  });

  @override
  Widget build(BuildContext context) {
    if (finishPlace != null) {
      return _badge('第$finishPlace名', Colors.amber);
    }
    if (passed) {
      return _badge('不要', Colors.white54);
    }
    if (cards == null || cards!.isEmpty) {
      return const SizedBox(width: 80, height: 60);
    }

    return SizedBox(
      height: CardWidget.baseHeight * 0.7 + 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: CardWidget.baseHeight * 0.7,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < cards!.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i > 0 ? -16.0 : 0),
                    child: CardWidget(
                      card: cards![i],
                      faceUp: true,
                      scale: 0.7,
                    ),
                  ),
              ],
            ),
          ),
          if (playerName != null)
            Text(
              playerName!,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
