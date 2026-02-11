import 'package:flutter/material.dart';
import 'package:guandan_shared/models/card.dart';

import 'card_widget.dart';

/// Dialog for the tribute phase (进贡).
/// The losing team gives their highest card(s) to the winning team,
/// who then returns a card of their choice.
class TributeDialog extends StatefulWidget {
  final List<GameCard> hand;
  final bool isGiving; // true = select card to give, false = select card to return
  final Rank currentLevel;

  const TributeDialog({
    super.key,
    required this.hand,
    required this.isGiving,
    required this.currentLevel,
  });

  @override
  State<TributeDialog> createState() => _TributeDialogState();
}

class _TributeDialogState extends State<TributeDialog> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B2B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isGiving ? '进贡' : '还贡',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isGiving
                  ? '选择一张牌进贡给对方'
                  : '选择一张牌还给对方',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 4,
              runSpacing: 8,
              children: [
                for (int i = 0; i < widget.hand.length; i++)
                  CardWidget(
                    card: widget.hand[i],
                    isSelected: _selectedIndex == i,
                    isWild: widget.hand[i].isWild(widget.currentLevel),
                    faceUp: true,
                    scale: 0.8,
                    onTap: () => setState(() => _selectedIndex = i),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectedIndex != null
                  ? () => Navigator.of(context)
                      .pop(widget.hand[_selectedIndex!])
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('确认', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
