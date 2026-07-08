import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/research/citation.dart';
import '../../providers/deep_link_provider.dart';
import '../../providers/reference_search_provider.dart';

/// Bottom sheet showing one cited source in full: reference + title, the
/// grounding snippet, and — when the SuttaCentral uid resolves to a BJT node
/// via the shared concordance — "Open in reader" and "Copy link" actions.
///
/// Unresolved citations (the concordance grows over time) still show the
/// snippet, with a gentle "not linked yet" note instead of the buttons.
class CitationSourceSheet extends ConsumerStatefulWidget {
  const CitationSourceSheet({super.key, required this.citation});

  final Citation citation;

  /// Opens the sheet. Resolves with `true` when the user chose
  /// "Open in reader" — the caller should then dismiss the chat dialog so the
  /// newly opened reader tab is visible.
  static Future<bool?> show(BuildContext context, Citation citation) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CitationSourceSheet(citation: citation),
    );
  }

  @override
  ConsumerState<CitationSourceSheet> createState() =>
      _CitationSourceSheetState();
}

class _CitationSourceSheetState extends ConsumerState<CitationSourceSheet> {
  /// Once true, the copy button reads "Link copied" until the sheet closes —
  /// a SnackBar would be hidden underneath the modal sheet.
  bool _copied = false;

  Future<void> _openInReader(String nodeKey) async {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    // Await the result: on a concordance-vs-tree miss the open fails, and
    // popping `true` regardless would also close the chat dialog with nothing
    // to show. The tree is already loaded here, so this resolves instantly.
    final opened = await ref.read(openTipitakaLinkProvider)(
      TipitakaLink(nodeKey: nodeKey),
      isPortraitMode: isPortrait,
    );
    if (!mounted) return;
    Navigator.of(context).pop(opened);
  }

  Future<void> _copyLink(String nodeKey) async {
    final url = ref
        .read(tipitakaLinkUrlBuilderProvider)(TipitakaLink(nodeKey: nodeKey));
    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final citation = widget.citation;

    // uid → BJT nodeKey via the shared concordance (same resolver instance
    // search-by-reference uses). Null while loading or when uncovered.
    final resolver = ref.watch(suttaCentralRefResolverProvider).valueOrNull;
    final nodeKey = resolver?.nodeKeyForUid(citation.uid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ─────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── "Cited source" label + heading + close ──────────────
          Text(
            l10n.researchCitedSource,
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  citation.title == null
                      ? citation.ref
                      : '${citation.ref} · ${citation.title}',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.close,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),

          // ── Snippet (scrolls when long) ──────────────────────────
          if (citation.snippet != null) ...[
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(
                  citation.snippet!,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Actions ─────────────────────────────────────────────
          if (nodeKey != null) ...[
            FilledButton.icon(
              onPressed: () => _openInReader(nodeKey),
              icon: const Icon(Icons.arrow_outward, size: 18),
              label: Text(l10n.researchOpenInReader),
            ),
            TextButton.icon(
              onPressed: _copied ? null : () => _copyLink(nodeKey),
              icon: Icon(_copied ? Icons.check : Icons.link, size: 18),
              label: Text(
                  _copied ? l10n.researchLinkCopied : l10n.researchCopyLink),
            ),
          ] else
            Text(
              l10n.researchCitationNotLinked,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
