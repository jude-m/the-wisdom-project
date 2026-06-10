/// Tab strip + per-tab layout switcher (the prototype's stand-in for the
/// app's tab_bar_widget + layout pill).
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';

import '../state/actions.dart';
import '../state/providers.dart';
import '../state/reader_tab.dart';

class ReaderTabBar extends StatelessComponent {
  const ReaderTabBar({super.key});

  @override
  Component build(BuildContext context) {
    final tabs = context.watch(tabsProvider);
    final active = context.watch(activeTabIndexProvider);

    return div(classes: 'tab-bar', [
      div(classes: 'tab-strip', [
        for (final (index, tab) in tabs.indexed)
          div(
            key: ValueKey('tab-${tab.id}'),
            classes: index == active ? 'tab active' : 'tab',
            attributes: {'title': tab.fullName},
            [
              span(
                classes: 'tab-label',
                events: {'click': (_) => activateTab(context, index)},
                [.text(tab.label)],
              ),
              span(
                classes: 'tab-close',
                events: {'click': (_) => closeTab(context, index)},
                [.text('×')],
              ),
            ],
          ),
      ]),
      if (active >= 0 && active < tabs.length)
        _layoutSwitcher(context, active, tabs[active].layout),
    ]);
  }

  Component _layoutSwitcher(
      BuildContext context, int activeIndex, ReaderLayout current) {
    Component option(ReaderLayout layout, String label, String tooltip) {
      return button(
        classes: current == layout ? 'layout-btn active' : 'layout-btn',
        attributes: {'title': tooltip},
        onClick: () =>
            context.read(tabsProvider.notifier).setLayout(activeIndex, layout),
        [.text(label)],
      );
    }

    return div(classes: 'layout-switcher', [
      option(ReaderLayout.paliOnly, 'පාළි', 'Pali only'),
      option(ReaderLayout.sinhalaOnly, 'සිංහල', 'Sinhala only'),
      option(ReaderLayout.sideBySide, 'පාළි | සිංහල', 'Side by side'),
    ]);
  }
}
