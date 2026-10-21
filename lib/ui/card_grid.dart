import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cards in one row when they fit, and a grid when the row would be too tight.
class CardGrid extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.children,
    this.minWidth = 160,
    this.gap = 12,
  });

  final List<Widget> children;
  final double minWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = math.max(1, (width / minWidth).floor());
        final across = math.min(columns, children.length);
        if (across == children.length) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) SizedBox(width: gap),
                Expanded(child: children[index]),
              ],
            ],
          );
        }
        final cardWidth = (width - gap * (across - 1)) / across;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}
