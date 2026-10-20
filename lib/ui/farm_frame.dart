import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';

/// Keeps the Android layout readable when the app is reviewed in a wide browser.
class FarmFrame extends StatelessWidget {
  const FarmFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: farmSand,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: child,
        ),
      ),
    );
  }
}

class FarmScrollBehavior extends MaterialScrollBehavior {
  const FarmScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
