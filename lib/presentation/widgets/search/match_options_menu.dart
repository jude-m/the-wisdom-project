import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/text_utils.dart';
import '../../providers/overlay_stack_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/search_state.dart';
import '../../providers/singlish_preview_provider.dart';
import '../common/pill_chip.dart';

/// How the words of a multi-word query sit together.
enum _Placement { phrase, anywhere, near }

_Placement _placementOf(SearchState s) => s.isPhraseSearch
    ? _Placement.phrase
    : (s.isAnywhereInText ? _Placement.anywhere : _Placement.near);

/// A second word has started: whitespace, then a non-space. Run on the
/// searched text, so " dhamma" or "%& x" count as one word, as they search.
final _severalWords = RegExp(r'\s\S');

/// What the button label shows. A record, so `select` rebuilds the button
/// only when one of these changes, not on every keystroke.
({bool exact, _Placement? placement, int? distance}) _labelOf(SearchState s) {
  final placement =
      _severalWords.hasMatch(s.effectiveQueryText) ? _placementOf(s) : null;
  return (
    exact: s.isExactMatch,
    placement: placement,
    distance: placement == _Placement.near ? s.proximityDistance : null,
  );
}

/// "Starts with ▾" in the filter row. Its label names the current match
/// options; tapping it opens the menu that changes them.
class MatchOptionsButton extends ConsumerStatefulWidget {
  const MatchOptionsButton({super.key});

  @override
  ConsumerState<MatchOptionsButton> createState() => _MatchOptionsButtonState();
}

class _MatchOptionsButtonState extends ConsumerState<MatchOptionsButton> {
  static const _overlayId = 'match-options-menu';

  final _menuController = MenuController();
  // Lets the arrow keys move from the button into the menu.
  final _buttonFocusNode = FocusNode(debugLabel: 'MatchOptionsButton');

  // Captured in initState: dispose() can't use `ref`.
  late final OverlayStackNotifier _overlayStack;

  @override
  void initState() {
    super.initState();
    _overlayStack = ref.read(overlayStackProvider.notifier);
  }

  @override
  void dispose() {
    // A menu closed because its button went away doesn't call onClose.
    // Riverpod forbids changing a provider while the tree is torn down, so
    // drop the entry once this frame ends.
    final stack = _overlayStack;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (stack.mounted) stack.remove(_overlayId);
    });
    _buttonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final label = ref.watch(searchStateProvider.select(_labelOf));

    final match = label.exact ? l10n.matchWholeWord : l10n.matchStartsWith;
    final text = switch (label.placement) {
      null => match,
      _Placement.phrase => '$match · ${l10n.matchPhraseShort}',
      _Placement.anywhere => '$match · ${l10n.matchAnywhereShort}',
      _Placement.near => '$match · ${l10n.matchNearShort(label.distance!)}',
    };

    return MenuAnchor(
      controller: _menuController,
      childFocusNode: _buttonFocusNode,
      alignmentOffset: const Offset(0, 4),
      // On the ESC stack while open, so ESC closes the menu and not the
      // results panel under it.
      onOpen: () => _overlayStack.push(
        DismissibleOverlay(id: _overlayId, dismiss: _menuController.close),
      ),
      onClose: () => _overlayStack.remove(_overlayId),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outline),
          ),
        ),
      ),
      menuChildren: const [_MatchMenu()],
      builder: (context, controller, child) => Tooltip(
        message: l10n.matchOptions,
        child: TextButton(
          focusNode: _buttonFocusNode,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          style: PillChip.styleOf(
            context,
            selected: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, maxLines: 1, softWrap: false),
              const SizedBox(width: 2),
              Icon(
                controller.isOpen ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The menu body. Built only while the menu is open, so its per-keystroke
/// watches cost nothing the rest of the time.
class _MatchMenu extends ConsumerWidget {
  const _MatchMenu();

  /// Width of each option's text; long lines wrap inside it.
  static const double textWidth = 236;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final options = ref.watch(searchStateProvider.select((s) => (
          exact: s.isExactMatch,
          placement: _placementOf(s),
          distance: s.proximityDistance,
          severalWords: _severalWords.hasMatch(s.effectiveQueryText),
        )));
    final rawQuery =
        ref.watch(searchStateProvider.select((s) => s.rawQueryText));
    final notifier = ref.read(searchStateProvider.notifier);

    // The examples use the words as shown in the search box: the Singlish
    // preview when there is one, which keeps ZWJ, so ්‍ර shows joined.
    // Words the search drops whole, like "%&", are left out.
    final shown = ref.watch(singlishPreviewProvider(rawQuery)) ?? rawQuery;
    final words = shown
        .replaceAll('\u200B', '')
        .split(RegExp(r'\s+'))
        .where((w) => sanitizeSearchQuery(w) != null)
        .toList();
    final hasWords = words.isNotEmpty;

    // Only the options on show count: with one word, the hidden "how words
    // sit" choice can't be seen to reset.
    const defaults = SearchState();
    final isDefault = options.exact == defaults.isExactMatch &&
        (!options.severalWords ||
            (options.placement == _placementOf(defaults) &&
                options.distance == defaults.proximityDistance));

    void setNear({int? distance}) => notifier.setMatchOptions(
          isPhraseSearch: false,
          isAnywhereInText: false,
          proximityDistance: distance,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.matchEachWord),
        _MatchOption<bool>(
          value: false,
          groupValue: options.exact,
          onSelected: (exact) => notifier.setMatchOptions(isExactMatch: exact),
          title: l10n.matchStartsWith,
          hint: l10n.matchStartsWithHint,
          example: !hasWords
              ? null
              : words.length == 1
                  ? '${words.first} · ${words.first}…'
                  : words.map((w) => '$w…').join(' · '),
        ),
        _MatchOption<bool>(
          value: true,
          groupValue: options.exact,
          onSelected: (exact) => notifier.setMatchOptions(isExactMatch: exact),
          title: l10n.matchWholeWord,
          hint: l10n.matchWholeWordHint,
          example:
              hasWords ? l10n.matchWholeWordExample(words.join(' · ')) : null,
        ),
        if (options.severalWords) ...[
          const Divider(height: 13),
          _SectionLabel(l10n.matchHowWordsSit),
          _MatchOption<_Placement>(
            value: _Placement.phrase,
            groupValue: options.placement,
            onSelected: (_) => notifier.setMatchOptions(
              isPhraseSearch: true,
              isAnywhereInText: false,
            ),
            title: l10n.matchPhrase,
            hint: l10n.matchPhraseHint,
            example: hasWords ? '“${words.join(' ')}”' : null,
          ),
          _MatchOption<_Placement>(
            value: _Placement.anywhere,
            groupValue: options.placement,
            onSelected: (_) => notifier.setMatchOptions(
              isPhraseSearch: false,
              isAnywhereInText: true,
            ),
            title: l10n.anywhereInText,
            hint: l10n.matchAnywhereHint,
            example: hasWords ? words.reversed.join(' · · · · · · ') : null,
          ),
          _MatchOption<_Placement>(
            value: _Placement.near,
            groupValue: options.placement,
            onSelected: (_) => setNear(),
            title: l10n.matchNear,
            hint: l10n.matchNearHint,
            example: hasWords ? words.join(' · · ') : null,
          ),
          // Changing the distance also picks "Near each other".
          _DistanceStepper(
            distance: options.distance,
            onChanged: (distance) => setNear(distance: distance),
          ),
        ],
        const Divider(height: 13),
        MenuItemButton(
          closeOnActivate: false,
          onPressed: isDefault
              ? null
              : () => notifier.setMatchOptions(
                    isExactMatch: defaults.isExactMatch,
                    isPhraseSearch: defaults.isPhraseSearch,
                    isAnywhereInText: defaults.isAnywhereInText,
                    proximityDistance: defaults.proximityDistance,
                  ),
          style: MenuItemButton.styleFrom(
            textStyle: context.typography.listRowTitle,
          ),
          child: Text(l10n.resetToDefault),
        ),
      ],
    );
  }
}

/// Section header inside the menu, e.g. "MATCH EACH WORD", styled like the
/// results panel's section headers.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: context.typography.sectionHeader,
      ),
    );
  }
}

/// One radio row: title, a grey line saying what it finds, and an example
/// built from the user's own words. Selecting it applies at once and keeps
/// the menu open.
class _MatchOption<T> extends StatelessWidget {
  final T value;
  final T groupValue;
  final ValueChanged<T> onSelected;
  final String title;
  final String hint;
  final String? example;

  const _MatchOption({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onSelected,
    required this.title,
    required this.hint,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = context.typography;
    final selected = value == groupValue;
    final example = this.example;

    return RadioMenuButton<T>(
      value: value,
      groupValue: groupValue,
      onChanged: (_) => onSelected(value),
      closeOnActivate: false,
      style: MenuItemButton.styleFrom(
        backgroundColor: selected ? colors.surfaceContainerLow : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: SizedBox(
        width: _MatchMenu.textWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: selected
                  ? typography.listRowTitle
                      .copyWith(fontWeight: FontWeight.w600)
                  : typography.listRowTitle,
            ),
            Text(hint, style: typography.menuSectionLabel),
            if (example != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  example,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typography.listRowTitle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Within 10 words  − +" under "Near each other". Range 1–100.
class _DistanceStepper extends StatelessWidget {
  final int distance;
  final ValueChanged<int> onChanged;

  const _DistanceStepper({required this.distance, required this.onChanged});

  static const int _min = 1;
  static const int _max = 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Where the option titles start: row padding, radio, then the menu's
    // gap after an icon (12, less at compact density).
    final textStart = 16 +
        Checkbox.width +
        math.max(4, 12 + theme.visualDensity.horizontal * 2);

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(textStart, 0, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.matchNearWithin(distance),
              style: context.typography.menuSectionLabel,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: l10n.fewerWords,
            onPressed: distance > _min ? () => onChanged(distance - 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: l10n.moreWords,
            onPressed: distance < _max ? () => onChanged(distance + 1) : null,
          ),
        ],
      ),
    );
  }
}
