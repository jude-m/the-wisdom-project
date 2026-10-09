import 'package:flutter/material.dart';

import 'mouse_drag_scroll.dart';
import 'right_edge_fade.dart';

/// One sideways-scrolling row of chips, faded out at the right edge so a cut
/// chip reads as "more this way". A mouse can drag it too.
class PillChipRow extends StatelessWidget {
  final List<Widget> children;

  const PillChipRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return RightEdgeFade(
      child: MouseDragScroll(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // Ends with room for the fade, so the last chip is clear of it once
          // scrolled to the end.
          padding: const EdgeInsetsDirectional.only(
            start: 4,
            end: RightEdgeFade.width,
          ),
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
