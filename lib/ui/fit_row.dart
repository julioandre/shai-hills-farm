import 'package:flutter/material.dart';

/// One row of cards. They share the width when they fit, and stack when they do not.
class FitRow extends StatelessWidget {
  const FitRow({
    super.key,
    required this.children,
    required this.height,
    this.minChildWidth = 160,
    this.gap = 12,
  });

  final List<Widget> children;
  final double height;
  final double minChildWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return SizedBox(height: height);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            minChildWidth * children.length + gap * (children.length - 1);
        if (constraints.maxWidth >= needed) {
          return SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) SizedBox(width: gap),
                  Expanded(child: children[index]),
                ],
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) SizedBox(height: gap),
              SizedBox(
                height: height,
                width: double.infinity,
                child: children[index],
              ),
            ],
          ],
        );
      },
    );
  }
}
