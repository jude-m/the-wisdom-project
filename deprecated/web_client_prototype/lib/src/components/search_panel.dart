/// FTS search box → results open into tabs (the real "find → open in tab"
/// flow from the spec).
///
/// The query pipeline reuses the app's pure-Dart logic IN-PROCESS — the
/// Jaspr-path payoff: computeEffectiveQuery does sanitize → Singlish→Sinhala
/// transliteration → ZWJ normalization, identical to the Flutter client,
/// with zero re-implementation.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';

import '../domain/fts_models.dart';
import '../state/actions.dart';
import '../state/providers.dart';
import '../utils/search_query_utils.dart';
import '../utils/text_utils.dart';

class SearchPanel extends StatefulComponent {
  const SearchPanel({super.key});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  String _rawQuery = '';
  String _effectiveQuery = '';
  List<FTSMatch> _results = const [];
  bool _searching = false;
  bool _searched = false;
  String? _error;

  Future<void> _runSearch() async {
    final effective = computeEffectiveQuery(_rawQuery);
    if (effective.isEmpty) return;

    setState(() {
      _effectiveQuery = effective;
      _searching = true;
      _error = null;
    });

    try {
      final results = await context
          .read(apiClientProvider)
          .searchFullText(effective, limit: 20);
      setState(() {
        _results = results;
        _searching = false;
        _searched = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Search failed: $e';
        _searching = false;
        _searched = true;
      });
    }
  }

  void _openResult(FTSMatch match) {
    openTab(
      context,
      name: '${match.filename} · ${match.eind}',
      fileId: match.filename,
      pageStart: match.pageIndex,
      entryAnchor: 'e-${match.pageIndex}-${match.language}-${match.entryIndex}',
    );
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'search-panel', [
      h2(classes: 'panel-title', [.text('සොයන්න')]),
      div(classes: 'search-box', [
        input(
          type: InputType.text,
          attributes: {'placeholder': 'Search… (Singlish works)'},
          onInput: (value) => _rawQuery = '$value',
          onChange: (value) {
            _rawQuery = '$value';
            _runSearch();
          },
        ),
        button(classes: 'search-btn', onClick: _runSearch, [.text('Go')]),
      ]),
      if (querySinglishConverted(_rawQuery, _effectiveQuery))
        div(classes: 'search-converted', [.text('→ $_effectiveQuery')]),
      if (_searching) div(classes: 'search-status', [.text('Searching…')]),
      if (_error != null) div(classes: 'search-error', [.text(_error!)]),
      if (_searched && !_searching && _results.isEmpty && _error == null)
        div(classes: 'search-status', [.text('No matches')]),
      div(classes: 'search-results', [
        for (final match in _results)
          div(
            classes: 'search-result',
            events: {'click': (_) => _openResult(match)},
            [
              div(classes: 'result-meta',
                  [.text('${match.filename} · ${match.language}')]),
              div(classes: 'result-snippet', [
                .text(truncateGraphemes(match.matchedText ?? '', 120)),
              ]),
            ],
          ),
      ]),
    ]);
  }
}
