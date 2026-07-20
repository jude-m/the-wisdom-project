import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-level app sections shown in the navigation rail (tablet/desktop) or
/// the bottom navigation bar (mobile).
///
/// Named "section" — not "tab" — because in this codebase "tab" already means
/// the reader's own document tabs (see tab_provider.dart).
enum AppSection { home, reader, research, notes }

/// The currently visible top-level section.
///
/// Defaults to the reader so a fresh launch lands exactly where the app
/// landed before the shell existed. Deliberately not persisted for now —
/// restarting always opens the reader.
final selectedAppSectionProvider =
    StateProvider<AppSection>((ref) => AppSection.reader);
