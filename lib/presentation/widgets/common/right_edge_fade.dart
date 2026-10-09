import 'package:flutter/material.dart';

/// Fades [child] out over its last [width] pixels on the right, so a cut item
/// reads as "more this way". End the row with [width] of padding, so the last
/// item is clear of the fade once scrolled to the end.
class RightEdgeFade extends StatelessWidget {
  static const double width = 24;

  final Widget child;

  const RightEdgeFade({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // A static method is the same callback on every build, so a rebuild (the
    // search panel rebuilds on each keystroke) doesn't repaint the mask.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: _fade,
      child: child,
    );
  }

  static Shader _fade(Rect bounds) => LinearGradient(
        colors: const [Colors.black, Colors.transparent],
        stops: [
          (1 - width / bounds.width).clamp(0.0, 1.0),
          1,
        ],
      ).createShader(bounds);
}
