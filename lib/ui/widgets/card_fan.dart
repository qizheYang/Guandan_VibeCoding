import 'package:flutter/material.dart';
import 'package:guandan_shared/models/card.dart';

import 'card_widget.dart';

class CardFan extends StatelessWidget {
  final List<GameCard> cards;
  final Set<int> selectedIndices;
  final Rank? currentLevel;
  final ValueChanged<int>? onCardTap;
  final double scale;

  const CardFan({
    super.key,
    required this.cards,
    this.selectedIndices = const {},
    this.currentLevel,
    this.onCardTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return SizedBox(height: CardWidget.baseHeight * scale + 16);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = CardWidget.baseWidth * scale;
        final maxWidth = constraints.maxWidth;
        final totalWidth = cards.length * cardWidth;

        // Calculate overlap
        double overlap = 0;
        if (cards.length > 1 && totalWidth > maxWidth) {
          overlap = (totalWidth - maxWidth) / (cards.length - 1);
          overlap = overlap.clamp(0.0, cardWidth * 0.7);
        }

        final effectiveWidth = cards.length > 1
            ? cardWidth + (cards.length - 1) * (cardWidth - overlap)
            : cardWidth;

        return SizedBox(
          height: CardWidget.baseHeight * scale + 18 * scale,
          width: effectiveWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < cards.length; i++)
                Positioned(
                  left: i * (cardWidth - overlap),
                  bottom: 0,
                  child: CardWidget(
                    card: cards[i],
                    isSelected: selectedIndices.contains(i),
                    isWild: currentLevel != null &&
                        cards[i].isWild(currentLevel!),
                    faceUp: true,
                    scale: scale,
                    onTap: onCardTap != null ? () => onCardTap!(i) : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
