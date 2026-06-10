import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'pages/home.dart';
import 'pages/sutta_page.dart';

/// Multi-page (server-side) routing: this component only runs on the server.
/// The client mounts the @client ReaderShell island directly.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return Router(routes: [
      Route(
        path: '/',
        title: 'The Wisdom Project',
        builder: (context, state) => const Home(),
      ),
      Route(
        path: '/sutta/:fileId',
        title: 'The Wisdom Project',
        builder: (context, state) => SuttaPage(
          fileId: state.params['fileId']!,
          initialPage: int.tryParse(state.queryParams['page'] ?? '') ?? 0,
        ),
      ),
    ]);
  }
}
