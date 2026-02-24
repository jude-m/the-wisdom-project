import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive_utils.dart';
import '../providers/breadcrumb_provider.dart';
import '../providers/navigator_sync_provider.dart';
import '../providers/tab_provider.dart';

/// Displays the active tab's position in the Tipitaka hierarchy as a
/// breadcrumb trail in the AppBar (e.g., "සුත්ත පිටකය › දීඝ නිකාය › බ්‍රහ්මජාලසුත්තං").
///
/// - Shows nothing (SizedBox.shrink) when no tab is active.
/// - Parent segments are tappable — opens a new tab for that node.
/// - Leaf segment (last) is non-tappable.
/// - Uses RichText so overflow truncates gracefully with ellipsis.
/// - Reacts to tab switches, tab closes, and navigation language changes.
class BreadcrumbWidget extends ConsumerStatefulWidget {
  const BreadcrumbWidget({super.key});

  @override
  ConsumerState<BreadcrumbWidget> createState() => _BreadcrumbWidgetState();
}

class _BreadcrumbWidgetState extends ConsumerState<BreadcrumbWidget> {
  // TapGestureRecognizer instances must be disposed to prevent memory leaks.
  // Recreated each build to match the current segment list.
  List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final segments = ref.watch(breadcrumbPathProvider);

    if (segments.isEmpty) return const SizedBox.shrink();

    // Dispose old recognizers before creating new ones
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers = [];

    final leafStyle = context.typography.resultSubtitle;
    // Parent segments use onSurface (brighter) to hint interactivity
    final parentStyle = leafStyle.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );
    final isPortrait = ResponsiveUtils.shouldDefaultToSingleColumn(context);

    final spans = <InlineSpan>[];
    for (int i = 0; i < segments.length; i++) {
      // Separator between segments
      if (i > 0) {
        spans.add(TextSpan(text: ' \u203A ', style: leafStyle));
      }

      if (i < segments.length - 1) {
        // Parent segment — clickable
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            ref.read(openTabFromNodeKeyProvider)(
              segments[i].nodeKey,
              isPortraitMode: isPortrait,
            );
            ref.read(syncNavigatorToActiveTabProvider)();
          };
        _recognizers.add(recognizer);

        spans.add(TextSpan(
          text: segments[i].displayName,
          style: parentStyle,
          recognizer: recognizer,
        ));
      } else {
        // Leaf segment — non-tappable
        spans.add(TextSpan(
          text: segments[i].displayName,
          style: leafStyle,
        ));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
