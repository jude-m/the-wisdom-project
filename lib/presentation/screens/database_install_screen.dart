import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n/app_localizations.dart';
import '../../core/theme/app_typography.dart';
import '../../data/database/database_installation.dart';
import '../providers/database_install_provider.dart';
import '../widgets/common/status_message_view.dart';

/// How long a start stays blank before the screen says anything.
///
/// A reload has nothing to download, but it still passes through
/// [DatabaseInstallPhase.checking] while the browser is probed and old
/// versions are swept. Without this the screen would flash a line it takes
/// straight back.
const Duration _quietStart = Duration(milliseconds: 400);

/// Megabytes as a download shows them: 1 MB = 1,000,000 bytes, which is what
/// the browser and the operating system report.
const int _bytesPerMb = 1000000;

/// Covers the app until the database it cannot start without is installed.
///
/// Only web installs anything — it downloads its databases on a first visit.
/// On native [DatabaseInstallation] is ready from the first frame, so [child]
/// is what builds and this costs a provider read.
class DatabaseInstallGate extends ConsumerWidget {
  const DatabaseInstallGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reading it starts the install; only the blocking database's status
    // arrives here, so a dictionary still downloading never covers the app.
    final status = ref.watch(databaseInstallProvider);
    if (status.phase == DatabaseInstallPhase.ready) return child;
    return DatabaseInstallScreen(
      status: status,
      onRetry: () => ref.read(databaseInstallProvider.notifier).retry(),
    );
  }
}

/// What the gate shows: one [DatabaseInstallStatus], in the four shapes it
/// comes in.
class DatabaseInstallScreen extends StatefulWidget {
  const DatabaseInstallScreen({
    super.key,
    required this.status,
    required this.onRetry,
  });

  final DatabaseInstallStatus status;
  final VoidCallback onRetry;

  @override
  State<DatabaseInstallScreen> createState() => _DatabaseInstallScreenState();
}

class _DatabaseInstallScreenState extends State<DatabaseInstallScreen> {
  Timer? _quietTimer;
  bool _quiet = true;

  @override
  void initState() {
    super.initState();
    _quietTimer = Timer(_quietStart, () {
      if (mounted) setState(() => _quiet = false);
    });
  }

  @override
  void dispose() {
    _quietTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    // A reload is usually past `checking` before the quiet start is over, and
    // should look like a normal start rather than a flash of text.
    if (_quiet && status.phase == DatabaseInstallPhase.checking) {
      return const Scaffold(body: SizedBox.expand());
    }

    return Scaffold(
      body: SafeArea(
        child: switch (status.phase) {
          DatabaseInstallPhase.failed =>
            _Failure(failure: status.failure, onRetry: widget.onRetry),
          DatabaseInstallPhase.installing => _Progress(status: status),
          // `ready` never reaches here — the gate shows the app instead.
          DatabaseInstallPhase.checking ||
          DatabaseInstallPhase.ready =>
            StatusMessageView(
              variant: StatusVariant.loading,
              title: AppLocalizations.of(context).databaseInstallPreparing,
            ),
        },
      ),
    );
  }
}

/// The download itself: how far it has got, and why it is happening at all.
class _Progress extends StatelessWidget {
  const _Progress({required this.status});

  final DatabaseInstallStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.typography;
    // Both null until the size is known, which leaves the bar indeterminate.
    final double? fraction = status.fraction;
    final String? progress = fraction == null
        ? null
        : l10n.databaseInstallProgress(
            status.received ~/ _bytesPerMb,
            status.total ~/ _bytesPerMb,
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.databaseInstallTitle,
                style: typography.emptyStateMessage,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
                // No semanticsValue: Flutter fills it with this same bare
                // percentage, clamped (`progress_indicator.dart`). The
                // megabytes are read from the line below, a `Text` like any
                // other.
                semanticsLabel: l10n.databaseInstallTitle,
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                Text(progress, style: typography.resultSubtitle),
              ],
              const SizedBox(height: 16),
              Text(
                // Every database together, not the one the bar is on: what a
                // first visit costs is worth knowing before it is spent.
                l10n.databaseInstallDescription(status.allTotal ~/ _bytesPerMb),
                style: typography.resultSubtitle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stopped install, in the three shapes a reader can do something about.
class _Failure extends StatelessWidget {
  const _Failure({required this.failure, required this.onRetry});

  final DatabaseInstallFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = failure?.kind ?? DatabaseInstallFailureKind.other;

    final (String title, String description) = switch (kind) {
      DatabaseInstallFailureKind.unsupportedBrowser => (
          l10n.databaseInstallUnsupportedTitle,
          l10n.databaseInstallUnsupportedDescription,
        ),
      DatabaseInstallFailureKind.outOfSpace => (
          l10n.databaseInstallOutOfSpaceTitle,
          l10n.databaseInstallOutOfSpaceDescription,
        ),
      DatabaseInstallFailureKind.download ||
      DatabaseInstallFailureKind.other =>
        (
          l10n.databaseInstallFailedTitle,
          l10n.databaseInstallFailedDescription
        ),
    };

    // Nothing about this browser would change on a second try, so it gets no
    // button. Everything else does.
    final retryable = kind != DatabaseInstallFailureKind.unsupportedBrowser;

    return Column(
      children: [
        Expanded(
          // Centred while there is room, scrollable when there is not: a short
          // window must not clip the screen that says what went wrong.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: StatusMessageView(
                  variant: kind == DatabaseInstallFailureKind.download
                      ? StatusVariant.offline
                      : StatusVariant.error,
                  title: title,
                  description: description,
                  action: retryable
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.databaseInstallRetry),
                          onPressed: onRetry,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        // The raw message, for the reader who reports what they saw. Left out
        // where the message above already says everything.
        if (failure != null && _showsDetail(kind))
          _Detail(message: failure!.message),
      ],
    );
  }

  static bool _showsDetail(DatabaseInstallFailureKind kind) =>
      kind == DatabaseInstallFailureKind.download ||
      kind == DatabaseInstallFailureKind.other;
}

class _Detail extends StatelessWidget {
  const _Detail({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      child: SelectableText(
        message,
        textAlign: TextAlign.center,
        maxLines: 3,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
