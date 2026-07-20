import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/api_error_type.dart';

/// Localised, user-ready message for an [ApiErrorType] — the 7-variant set from
/// the gold-standard plan (§2). The repository-layer mapper carries only English
/// fallbacks; this is where the app's real, translated copy is chosen.
String researchErrorMessage(AppLocalizations l10n, ApiErrorType type) =>
    switch (type) {
      ApiErrorType.offline => l10n.researchErrorOffline,
      ApiErrorType.timeout => l10n.researchErrorTimeout,
      ApiErrorType.rateLimited => l10n.researchErrorRateLimited,
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
