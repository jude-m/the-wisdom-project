/// Server-only page for /sutta/`fileId`.
///
/// Fetches the document from the shelf API DURING SSR (PreloadStateMixin),
/// slices the initial page window, and renders the [ReaderShell] island with
/// it — so the sutta text is in the initial HTML (crawlable) AND seeds the
/// client tab workspace (deep link → first tab).
///
/// This component never runs on the client (only @client components do), so
/// it may freely use server-side facilities.
library;

import 'dart:convert';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import '../src/data/api_client.dart';
import '../src/nav_items.dart';
import '../src/components/reader_shell.dart';

/// How many pages the server renders into the initial HTML. Small on
/// purpose: the window is also embedded as island params for hydration,
/// so it directly adds to page weight (~5–15KB for 2 BJT pages).
const _ssrPageWindow = 2;

class SuttaPage extends StatefulComponent {
  const SuttaPage({required this.fileId, this.initialPage = 0, super.key});

  final String fileId;

  /// Optional ?page= query param (e.g. future search deep links).
  final int initialPage;

  @override
  State<SuttaPage> createState() => _SuttaPageState();
}

class _SuttaPageState extends State<SuttaPage>
    with PreloadStateMixin<SuttaPage> {
  String? _windowJson;
  int _pageStart = 0;
  int _totalPages = 0;
  String? _error;

  @override
  Future<void> preloadState() async {
    try {
      final json = await WisdomApiClient().fetchTextJson(component.fileId);
      final pages = json['pages'] as List<dynamic>;
      _totalPages = pages.length;
      _pageStart = component.initialPage.clamp(0, _totalPages - 1);
      final window = pages.sublist(
        _pageStart,
        (_pageStart + _ssrPageWindow).clamp(0, _totalPages),
      );
      // Re-encode only the window — this is what gets SSR-rendered and
      // embedded as hydration params.
      _windowJson = jsonEncode({
        'filename': json['filename'],
        'pages': window,
      });
    } catch (e) {
      _error = 'Could not load "${component.fileId}": $e';
    }
  }

  @override
  Component build(BuildContext context) {
    if (_error != null || _windowJson == null) {
      return div(classes: 'load-error', [
        h2([.text('Text not available')]),
        p([.text(_error ?? 'Unknown error')]),
        a(href: '/', [.text('← Home')]),
      ]);
    }

    return ReaderShell(
      fileId: component.fileId,
      suttaName: displayNameFor(component.fileId),
      initialPageStart: _pageStart,
      totalPages: _totalPages,
      initialWindowJson: _windowJson!,
    );
  }
}
