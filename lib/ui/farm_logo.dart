import 'package:flutter/material.dart';

/// The Katamansu Spice Farm mark.
class FarmLogo extends StatelessWidget {
  const FarmLogo({super.key, this.width = 220});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/logo.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'Katamansu Spice Farm',
    );
  }
}
