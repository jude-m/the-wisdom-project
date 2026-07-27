/// Server-rendered landing page: plain anchors to the sutta pages.
/// Multi-page routing means these are real <a href> links in the HTML —
/// exactly what a crawler wants.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../src/nav_items.dart';

class Home extends StatelessComponent {
  const Home({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'home', [
      h1([.text('The Wisdom Project')]),
      p(classes: 'home-sub', [
        .text('Jaspr web prototype — SSR + hydrated multi-tab reader'),
      ]),
      ul(classes: 'home-list', [
        for (final item in navSuttas)
          li([
            a(href: '/sutta/${item.fileId}', [.text(item.name)]),
          ]),
      ]),
    ]);
  }
}
