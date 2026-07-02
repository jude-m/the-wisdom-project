import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/api_error_type.dart';

/// Localised, user-ready message for an [ApiErrorType] — the 7-variant set from
/// the gold-standard plan (§2). The repository-layer mapper carries only English
/// fallbacks; this is where the app's real, translated copy is chosen.
String askErrorMessage(AppLocalizations l10n, ApiErrorType type) =>
    switch (type) {
      ApiErrorType.offline => l10n.askErrorOffline,
      ApiErrorType.timeout => l10n.askErrorTimeout,
      ApiErrorType.rateLimited => l10n.askErrorRateLimited,
      ApiErrorType.serviceBusy => l10n.askErrorServiceBusy,
      ApiErrorType.notAuthorised => l10n.askErrorNotAuthorised,
      ApiErrorType.cannotAnswer => l10n.askErrorCannotAnswer,
      ApiErrorType.serverError => l10n.askErrorServerError,
    };

/// Whether the dialog should offer a one-tap Retry for this type.
///
/// `notAuthorised` is a build/config problem — retrying is a lie. `cannotAnswer`
/// needs the user to *rephrase*, not re-send the identical text (the dialog
/// restores their question to the input instead). Everything else is retriable.
bool canRetryType(ApiErrorType type) => switch (type) {
      ApiErrorType.notAuthorised || ApiErrorType.cannotAnswer => false,
      ApiErrorType.offline ||
      ApiErrorType.timeout ||
      ApiErrorType.rateLimited ||
      ApiErrorType.serviceBusy ||
      ApiErrorType.serverError =>
        true,
    };
