import 'package:flutter/material.dart';
import 'package:guandan_shared/models/card.dart';

import 'card_widget.dart';

class CardFan extends StatelessWidget {
  final List<GameCard> cards;
  final Set<int> selectedIndices;
  final Rank? currentLevel;
  final ValueChanged<int>? onCardTap;

  const CardFan({
    super.key,
    required this.cards,
    this.selectedIndices = const {},
    this.currentLevel,
    this.onCardTap,
  });

  /// Same-rank cards overlap heavily — just a sliver visible.
  static const double _sameRankFraction = 0.15;

  /// Minimum spacing between different-rank cards (fraction of card width).
  static const double _minDiffRankFraction = 0.25;

  /// Maximum spacing between different-rank cards (no more than this).
  static const double _maxDiffRankFraction = 0.85;

  /// Cards won't shrink below this scale.
  static const double _minScale = 0.4;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return SizedBox(height: CardWidget.baseHeight + 16);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final n = cards.length;

        // Count same-rank gaps vs different-rank gaps
        int sameRankGaps = 0;
        for (int i = 1; i < n; i++) {
          if (cards[i].rank == cards[i - 1].rank) sameRankGaps++;
        }
        final diffRankGaps = n - 1 - sameRankGaps;

        // Calculate minimum total width at scale 1.0
        // (maximum overlap for both same-rank and different-rank)
        final baseW = CardWidget.baseWidth;
        final minWidthAtScale1 = baseW +
            sameRankGaps * baseW * _sameRankFraction +
            diffRankGaps * baseW * _minDiffRankFraction;

        // Determine scale to fit within available width
        double scale = 1.0;
        if (n > 1 && minWidthAtScale1 > maxWidth) {
          scale = maxWidth / minWidthAtScale1;
        }
        scale = scale.clamp(_minScale, 1.0);

        final cardW = baseW * scale;
        final cardH = CardWidget.baseHeight * scale;
        final sameOffset = cardW * _sameRankFraction;

        // Calculate different-rank offset to fill available width
        double diffOffset;
        if (diffRankGaps > 0) {
          diffOffset =
              (maxWidth - cardW - sameRankGaps * sameOffset) / diffRankGaps;
          diffOffset = diffOffset.clamp(
            cardW * _minDiffRankFraction,
            cardW * _maxDiffRankFraction,
          );
        } else {
          diffOffset = sameOffset;
        }

        // Build positions for each card
        final positions = <double>[0];
        for (int i = 1; i < n; i++) {
          final isSameRank = cards[i].rank == cards[i - 1].rank;
          positions
              .add(positions.last + (isSameRank ? sameOffset : diffOffset));
        }

        final totalWidth = positions.last + cardW;
        final offsetX = (maxWidth - totalWidth).clamp(0.0, maxWidth) / 2;

        return SizedBox(
          height: cardH + 18 * scale,
          width: maxWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < n; i++)
                Positioned(
                  left: offsetX + positions[i],
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
