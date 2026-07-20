import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/research/citation.dart';
import 'citation_source_sheet.dart';

/// Renders a research answer as rich text: a small Markdown subset
/// (`**bold**`, `*italic*`, `- ` bullets, blank-line paragraphs) with inline
/// `[[cite:uid]]` citation chips that open the [CitationSourceSheet] "peek".
///
/// Deliberately knows nothing about its host: "Open in reader" inside the
/// peek switches the app to the Reader section via the deep-link provider,
/// so the Research chat view drops this in with no wiring.
class ResearchAnswerView extends StatelessWidget {
  const ResearchAnswerView({
    super.key,
    required this.answer,
    required this.citations,
  });

  /// Answer prose from `/research`, carrying inline `[[cite:uid]]` markers plus
  /// the small Markdown subset (see class doc).
  final String answer;

  /// Sources for the answer — chips are looked up here by uid.
  final List<Citation> citations;

  /// One inline token: a citation marker, `**bold**`, or `*italic*`. Bold is
  /// listed before italic so `**x**` matches the bold arm, not two italics.
  static final RegExp _inline =
      RegExp(r'\[\[cite:([^\]\s]+)\]\]|\*\*(.+?)\*\*|\*(.+?)\*');

  /// A leading list bullet (`- ` or `* `) at the start of a line.
  static final RegExp _bullet = RegExp(r'^\s*[-*]\s+');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final citationsByUid = {for (final c in citations) c.uid: c};
    final blocks = _parseBlocks(answer);

    // uids already rendered as inline chips — so we never repeat one below.
    final inlineUids = _inline
        .allMatches(answer)
        .map((m) => m.group(1))
        .whereType<String>()
        .toSet();
    final otherSources =
        citations.where((c) => !inlineUids.contains(c.uid)).toList();

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 8));
      children.add(_buildBlock(context, blocks[i], citationsByUid));
    }

    // Sources Gemini grounded on that the answer didn't name inline (cited by
    // retrieval, not written into the prose). Shown once, at the bottom, under a
    // heading — never duplicating an inline chip.
    if (otherSources.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(_buildOtherSources(context, l10n, otherSources));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildOtherSources(
    BuildContext context,
    AppLocalizations l10n,
    List<Citation> sources,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.researchOtherSources,
          style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in sources) _CitationChip(citation: c),
          ],
        ),
      ],
    );
  }

  /// Splits the answer into paragraph / bullet blocks. Consecutive non-blank,
  /// non-bullet lines coalesce into one paragraph (LLM soft line breaks); blank
  /// lines separate paragraphs.
  List<({bool bullet, String text})> _parseBlocks(String src) {
    final blocks = <({bool bullet, String text})>[];
    final para = <String>[];

    void flushParagraph() {
      if (para.isNotEmpty) {
        blocks.add((bullet: false, text: para.join(' ')));
        para.clear();
      }
    }

    for (final rawLine in src.split('\n')) {
      final line = rawLine.trim();
      if (_bullet.hasMatch(line)) {
        flushParagraph();
        blocks.add((bullet: true, text: line.replaceFirst(_bullet, '')));
      } else if (line.isEmpty) {
        flushParagraph();
      } else {
        para.add(line);
      }
    }
    flushParagraph();
    return blocks;
  }

  Widget _buildBlock(
    BuildContext context,
    ({bool bullet, String text}) block,
    Map<String, Citation> citationsByUid,
  ) {
    final textWidget = Text.rich(
      TextSpan(children: _inlineSpans(context, block.text, citationsByUid)),
    );
    if (!block.bullet) return textWidget;

    // Bullet item: a small dot + the (rich) line.
    final dotColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, left: 2, right: 8),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        Expanded(child: textWidget),
      ],
    );
  }

  /// Tokenises one block into spans: plain text, bold/italic runs, and a
  /// [_CitationChip] `WidgetSpan` for each `[[cite:uid]]` marker.
  List<InlineSpan> _inlineSpans(
    BuildContext context,
    String text,
    Map<String, Citation> citationsByUid,
  ) {
    final spans = <InlineSpan>[];
    var last = 0;

    for (final m in _inline.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }

      final uid = m.group(1);
      final bold = m.group(2);
      final italic = m.group(3);

      if (uid != null) {
        // Unknown uid (shouldn't happen — the server guarantees every marker's
        // uid is in `citations`): drop the chip rather than render a dead one.
        final citation = citationsByUid[uid];
        if (citation != null) {
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _CitationChip(citation: citation),
          ));
        }
      } else if (bold != null) {
        spans.add(TextSpan(
          text: bold,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (italic != null) {
        spans.add(TextSpan(
          text: italic,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }

      last = m.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}

/// The inline citation pill: a book glyph + the reference (e.g. "SN 12.2").
/// Tapping opens the [CitationSourceSheet] peek.
class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.citation});

  final Citation citation;

  void _open(BuildContext context) {
    CitationSourceSheet.show(context, citation);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      // A hair of horizontal breathing room so the chip doesn't hug the prose.
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book,
                    size: 13, color: colors.onPrimaryContainer),
                const SizedBox(width: 3),
                Text(
                  citation.ref,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
