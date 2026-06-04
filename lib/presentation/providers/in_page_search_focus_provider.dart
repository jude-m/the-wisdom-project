import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the `FocusNode` for the in-page (find-in-page) search bar.
///
/// Riverpod creates the node lazily on first read and disposes it (via
/// `ref.onDispose`) when the `ProviderScope` is torn down — i.e. once for the
/// whole session. `InPageSearchBar` *borrows* this node for its `TextField`
/// instead of creating its own, and `OpenInPageSearchAction` reads it to call
/// `requestFocus()` so Ctrl/Cmd+F snaps focus back to an already-open bar
/// (Chrome / VS Code muscle memory).
///
/// Why a `Provider` that owns the node rather than a `StateProvider<FocusNode?>`
/// the widget pushes into: the bar is transient (mounted/unmounted per
/// `isVisible`, re-keyed per tab) but the node must be reachable from the
/// always-mounted global shortcut handler. Letting the widget publish/clear a
/// disposable object through its own lifecycle meant the provider could hold a
/// disposed node, and writing to it inside `dispose()` re-entered Riverpod's
/// scheduler mid-teardown and crashed ("_lifecycleState != defunct"). Owning
/// the node here keeps the widget a pure consumer that never writes provider
/// state — the whole race disappears.
///
/// Mirror of `mainSearchFocusNodeProvider`.
final inPageSearchFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'in-page-search');
  ref.onDispose(node.dispose);
  return node;
});
