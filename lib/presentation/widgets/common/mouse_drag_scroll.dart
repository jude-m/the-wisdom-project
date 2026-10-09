import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets a mouse drag the scrollable in [child], as touch can: Flutter leaves
/// the mouse out on desktop and web. For sideways rows. No scrollbar or
/// overscroll effect.
class MouseDragScroll extends StatelessWidget {
  final Widget child;

  const MouseDragScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        scrollbars: false,
        overscroll: false,
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: child,
    );
  }
}
