import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../providers/parallel_text_provider.dart';

/// A button that allows navigation between root text and its parallel text
/// (commentary/atthakatha).
///
/// Displays:
/// - "Commentary" when viewing root text (links to atthakatha)
/// - "Root Text" when viewing commentary (links to sutta)
/// - Hidden when no valid parallel text exists
class ParallelTextButton extends ConsumerWidget {
  const ParallelTextButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the target node to determine if button should be shown
    final targetNode = ref.watch(parallelTextNodeProvider);

    // Hide button if no valid target exists
    if (targetNode == null) {
      return const SizedBox.shrink();
    }

    // Determine if we're currently viewing a commentary
    final isCommentary = ref.watch(isCommentaryProvider);
    final l10n = AppLocalizations.of(context);

    // Button label based on current content type
    final buttonLabel = isCommentary ? l10n.rootText : l10n.commentary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextButton.icon(
        onPressed: () => ref.read(openParallelTextProvider)(),
        icon: Icon(
          isCommentary ? Icons.article_outlined : Icons.menu_book_outlined,
          size: 18,
        ),
        label: Text(buttonLabel),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}
