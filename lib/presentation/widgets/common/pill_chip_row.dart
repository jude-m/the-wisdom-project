import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// One sideways-scrolling row of chips, faded out at the right edge so a cut
/// chip reads as "more this way". Mouse and trackpad can drag it too.
class PillChipRow extends StatelessWidget {
  final List<Widget> children;

  const PillChipRow({super.key, required this.children});

  static const double _fadeWidth = 24;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: const [Colors.black, Colors.transparent],
        stops: [
          (1 - _fadeWidth / bounds.width).clamp(0.0, 1.0),
          1,
        ],
      ).createShader(bounds),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
          scrollbars: false,
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // Ends with room for the fade, so the last chip is clear of it once
          // scrolled to the end.
          padding: const EdgeInsetsDirectional.only(start: 4, end: _fadeWidth),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: children.length,
          separatorBuilder: (context, index) => const SizedBox(width: 6),
          // Center: the list would otherwise stretch each chip to its height.
          itemBuilder: (context, index) => Center(child: children[index]),
        ),
      ),
    );
  }
}
