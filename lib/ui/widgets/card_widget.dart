import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:guandan_shared/models/card.dart';

class CardWidget extends StatelessWidget {
  final GameCard card;
  final bool isSelected;
  final bool faceUp;
  final bool isWild;
  final VoidCallback? onTap;
  final double scale;

  static const double baseWidth = 60;
  static const double baseHeight = 84;

  const CardWidget({
    super.key,
    required this.card,
    this.isSelected = false,
    this.faceUp = true,
    this.isWild = false,
    this.onTap,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final w = baseWidth * scale;
    final h = baseHeight * scale;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: isSelected
            ? Matrix4.translationValues(0, -14 * scale, 0)
            : Matrix4.identity(),
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6 * scale),
          border: isWild
              ? Border.all(color: Colors.amber, width: 2.5 * scale)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.black26,
              blurRadius: isSelected ? 6 : 2,
              offset: Offset(1 * scale, 1 * scale),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6 * scale),
          child: faceUp
              ? SvgPicture.asset(
                  card.assetPath,
                  width: w,
                  height: h,
                  fit: BoxFit.contain,
                )
              : SvgPicture.asset(
                  GameCard.backAssetPath,
                  width: w,
                  height: h,
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }
}

/// A smaller card back for showing opponent card counts.
class CardBackMini extends StatelessWidget {
  final double scale;

  const CardBackMini({super.key, this.scale = 0.5});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: CardWidget.baseWidth * scale,
      height: CardWidget.baseHeight * scale,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4 * scale),
        child: SvgPicture.asset(
          GameCard.backAssetPath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
