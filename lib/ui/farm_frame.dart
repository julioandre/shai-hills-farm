import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The app fills the window. Phone, tablet, and desktop share this frame.
class FarmFrame extends StatelessWidget {
  const FarmFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
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
