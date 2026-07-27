/// Minimal navigator: a hardcoded list of content files that open into tabs
/// client-side (no page reload — this is the hydrated island working).
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../nav_items.dart';
import '../state/actions.dart';

class NavPanel extends StatelessComponent {
  const NavPanel({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'nav-panel', [
      h2(classes: 'panel-title', [.text('සූත්‍ර')]),
      ul(classes: 'nav-list', [
        for (final item in navSuttas)
          li(
            classes: 'nav-item',
            events: {
              'click': (_) =>
                  openTab(context, name: item.name, fileId: item.fileId),
            },
            [.text(item.name)],
          ),
      ]),
    ]);
  }
}
