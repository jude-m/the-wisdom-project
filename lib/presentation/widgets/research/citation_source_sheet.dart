import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

import '../../../core/constants/constants.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/research/citation.dart';
import '../../providers/deep_link_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/navigation_tree_provider.dart';
import '../../providers/reference_search_provider.dart';
import '../../providers/research_provider.dart';
import '../reader/reader_entry_builder.dart';

/// Bottom-sheet "peek" for one cited source. Two complementary blocks:
///
/// - **Matched passage (SuttaCentral, English)** — `citation.snippet`, the span
///   the answer was grounded on, with matched terms in **bold**. This is the
///   *why it was cited* provenance; the RAG corpus is English-only.
/// - **From the sutta (BJT, Sinhala)** — the opening of the resolved BJT sutta,
///   under its Sinhala title. This is *what "Open in reader" will show* (the app
///   holds no English). The two blocks intentionally aren't aligned — they do
///   different jobs — so no cross-edition alignment is attempted.
///
/// Unresolved citations (the concordance grows over time) still show the English
/// snippet, with a gentle "not linked yet" note instead of the Sinhala block and
/// the action buttons.
class CitationSourceSheet extends ConsumerStatefulWidget {
  const CitationSourceSheet({super.key, required this.citation});

  final Citation citation;

  /// Opens the sheet. "Open in reader" switches the app to the Reader
  /// section itself (via the deep-link provider), so there is nothing to
  /// report back to the caller.
  static Future<void> show(BuildContext context, Citation citation) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Rise at the answer column's width, not the whole app width. The
      // sheet centers within the nearest Navigator — the Research screen's
      // chat-area navigator (_ChatArea) — so with the column's own max
      // width it lands exactly over the answers. On mobile the screen is
      // narrower than this, so the constraint is inert there.
      constraints: const BoxConstraints(
        maxWidth: PaneWidthConstants.researchContentMaxWidth,
      ),
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
    // Await the open (the tree is already loaded, so it resolves instantly)
    // so the Reader section is showing by the time the sheet slides away.
    await ref.read(openTipitakaLinkProvider)(
      TipitakaLink(nodeKey: nodeKey),
      isPortraitMode: isPortrait,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
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

    // On desktop the modal barrier only spans the chat-area navigator, so
    // the history panel stays clickable — if the user switches or deletes
    // the chat underneath, this peek no longer belongs to what's shown.
    ref.listen(researchChatProvider.select((s) => s.sessionId), (prev, next) {
      if (prev != next) Navigator.of(context).pop();
    });

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
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          // ── Scrollable body: English snippet + Sinhala opening ──
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // English (SuttaCentral) — the matched span, bold on matches.
                  if (citation.snippet != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.researchMatchedPassage,
                      style: textTheme.labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    SelectableText.rich(
                      TextSpan(
                        style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant, height: 1.5),
                        children: _boldSpans(citation.snippet!),
                      ),
                    ),
                  ],

                  // Sinhala (BJT) — the opening of the resolved sutta.
                  if (nodeKey != null) _SinhalaSourcePreview(nodeKey: nodeKey),
                ],
              ),
            ),
          ),
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

final _boldMarker = RegExp(r'\*\*(.+?)\*\*');

/// Splits `**bold**`-marked snippet text into spans. The snippet only ever
/// carries `**` (from `make_snippet`), so a single-marker parse is enough.
List<InlineSpan> _boldSpans(String text) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _boldMarker.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    spans.add(TextSpan(
      text: m.group(1),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

/// The BJT-Sinhala opening of the resolved sutta, under its Sinhala title —
/// the "what you'll open" preview. Loads the node's document and renders the
/// first few Sinhala entries with the reader's own entry styling.
class _SinhalaSourcePreview extends ConsumerWidget {
  const _SinhalaSourcePreview({required this.nodeKey});

  final String nodeKey;

  /// How many entries from the sutta's start to preview (a display cap, not a
  /// search) — enough to give a taste, not the whole sutta.
  static const _maxEntries = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeByKeyProvider(nodeKey));
    if (node == null || !node.isReadableContent) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final docAsync = ref.watch(bjtDocumentProvider(node.contentFileId!));

    return docAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (doc) {
        final page = doc.getPageByIndex(node.entryPageIndex);
        final entries = page?.sinhalaSection.entries ?? const [];
        if (entries.isEmpty) return const SizedBox.shrink();

        final start = node.entryIndexInPage.clamp(0, entries.length);
        final preview =
            entries.sublist(start, (start + _maxEntries).clamp(0, entries.length));
        // A sutta starting at the last entry slices to nothing — don't render a
        // lone title with no body.
        if (preview.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            // Sinhala title of the BJT sutta — what "Open in reader" opens.
            Text(
              node.sinhalaName,
              style: textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            for (final entry in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ReaderEntryBuilder.buildEntry(context, entry),
              ),
          ],
        );
      },
    );
  }
}
