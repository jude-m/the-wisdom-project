import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/api_error_type.dart';
import '../../../domain/entities/research/research_mode.dart';

/// Localised, user-ready message for an [ApiErrorType] — the variant set from
/// the gold-standard plan (§2). The repository-layer mapper carries only English
/// fallbacks; this is where the app's real, translated copy is chosen.
///
/// [mode] is the Fast/Thinking tier a retry would use. It only changes the
/// rate-limited copy: in Thinking mode we add a hint to switch to Fast (which
/// has more quota); Fast mode is already the most generous, so no hint.
String researchErrorMessage(
  AppLocalizations l10n,
  ApiErrorType type, {
  ResearchMode mode = ResearchMode.fast,
}) =>
    switch (type) {
      ApiErrorType.offline => l10n.researchErrorOffline,
      ApiErrorType.timeout => l10n.researchErrorTimeout,
      ApiErrorType.rateLimited => mode == ResearchMode.thinking
          ? l10n.researchErrorRateLimitedThinking
          : l10n.researchErrorRateLimited,
      ApiErrorType.serviceBusy => l10n.researchErrorServiceBusy,
      ApiErrorType.notAuthorised => l10n.researchErrorNotAuthorised,
      ApiErrorType.cannotAnswer => l10n.researchErrorCannotAnswer,
      ApiErrorType.serverError => l10n.researchErrorServerError,
      ApiErrorType.resourceLimit => l10n.researchErrorResourceLimit,
    };

/// Whether the chat view should offer a one-tap Retry for this type.
///
/// `notAuthorised` is a build/config problem — retrying is a lie. `cannotAnswer`
/// needs the user to *rephrase*, not re-send the identical text (the chat view
/// restores their question to the input instead). Everything else is retriable.
bool canRetryType(ApiErrorType type) => switch (type) {
      ApiErrorType.notAuthorised || ApiErrorType.cannotAnswer => false,
      ApiErrorType.offline ||
      ApiErrorType.timeout ||
      ApiErrorType.rateLimited ||
      ApiErrorType.serviceBusy ||
      ApiErrorType.serverError ||
      ApiErrorType.resourceLimit =>
        true,
    };
