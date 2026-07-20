import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n/app_localizations.dart';
import '../../core/utils/responsive_utils.dart';
import '../providers/research_provider.dart';
import '../widgets/research/chat_history_panel.dart';
import '../widgets/research/research_chat_view.dart';
import '../widgets/research/research_mode_selector.dart';

/// The Research section: a multi-chat AI Q&A UI (Stage 2 of the app-shell
/// plan, superseding the v1 ResearchChatDialog).
///
/// - Desktop/tablet: persistent left panel with the saved chats, beside the
///   conversation — like the familiar chat apps.
/// - Mobile: the same panel inside a [Drawer]; the app bar shows the active
///   chat's title with the section name as a subtitle (mobile mockup).
///
/// Chat state lives in the app-lifetime [researchChatProvider]; transcripts
/// persist through [chatHistoryRepositoryProvider] (max 25, local-only).
class ResearchScreen extends ConsumerWidget {
  const ResearchScreen({super.key});

  static const _panelWidth = 280.0;

  /// The Fast/Thinking switch, shown top-right of the app bar. One shared list
  /// so the desktop and mobile layouts stay identical (and can't drift).
  static const _appBarActions = [
    Padding(
      padding: EdgeInsets.only(right: 12),
      child: ResearchModeSelector(),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final isTabletOrDesktop = ResponsiveUtils.isTabletOrDesktop(context);

    if (isTabletOrDesktop) {
      return Scaffold(
        appBar: AppBar(
          // Match the Reader app bar's resting tone.
          backgroundColor: colors.surfaceContainerLow,
          title: Text(l10n.navResearch),
          actions: _appBarActions,
        ),
        body: Row(
          children: [
            // Persistent history panel — same border treatment as the
            // Reader's tree navigator.
            Container(
              width: _panelWidth,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: const ChatHistoryPanel(),
            ),
            const Expanded(child: _ChatArea()),
          ],
        ),
      );
    }

    // Mobile: drawer for the history; title = active chat (or the section
    // name for a fresh canvas). Only the title is watched here, so typing
    // and streaming answers don't rebuild the scaffold.
    final activeTitle = ref.watch(
      researchChatProvider.select(
        (s) => s.messages.isEmpty ? null : s.messages.first.content,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surfaceContainerLow,
        title: activeTitle == null
            ? Text(l10n.navResearch)
            : Column(
                // Shrink-wrap so the AppBar centers the two lines vertically
                // (max would pin them to the top of the toolbar).
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activeTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    l10n.navResearch,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
        actions: _appBarActions,
      ),
      // The AppBar gets its hamburger automatically from this drawer.
      drawer: Drawer(
        child: SafeArea(
          child: Builder(
            // Builder gives the panel a context below the Drawer, so
            // popping closes the drawer (it's a local history entry).
            builder: (drawerContext) => ChatHistoryPanel(
              onChatSelected: () => Navigator.of(drawerContext).pop(),
            ),
          ),
        ),
      ),
      body: const SafeArea(child: ResearchChatView()),
    );
  }
}

/// Hosts the chat view inside its own [Navigator], so modals opened from the
/// conversation — the citation peek sheet — lay out within the CHAT AREA
/// (centered over the answer column) instead of the whole window, which on
/// desktop is offset by the history panel and the nav rail. Same visual
/// result as the dictionary sheet's inline centering, but the modal route
/// semantics (barrier tap, ESC, drag-to-dismiss) stay native.
///
/// The [NavigatorPopHandler] forwards the system back gesture to this
/// navigator — the tablet/desktop split is width-based, so an Android
/// tablet lands here too, and system back only reaches the ROOT navigator
/// on its own (it wouldn't close the sheet otherwise).
///
/// Tablet/desktop layout ONLY: the mobile body is already exactly the chat
/// area, so nesting there would add nothing.
class _ChatArea extends StatefulWidget {
  const _ChatArea();

  @override
  State<_ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<_ChatArea> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (result) => _navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const ResearchChatView(),
        ),
      ),
    );
  }
}
