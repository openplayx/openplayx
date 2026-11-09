import '../../data/configuration/source_credential_broker.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';

/// Host-owned status translations; source services stay independent of Widgets.
abstract final class SourcePresentation {
  static String application(
    AppLocalizations l,
    SourceApplicationStatus status,
  ) => switch (status) {
    SourceApplicationStatus.disabled => l.disabled,
    SourceApplicationStatus.ready => l.sourceReady,
    SourceApplicationStatus.failed => l.sourceConnectionFailed,
    SourceApplicationStatus.initialized => l.sourceInitialized,
    SourceApplicationStatus.saved => l.sourceSaved,
  };
  static String credential(AppLocalizations l, SourceAuthorization status) =>
      switch (status) {
        SourceAuthorization.notRequired => l.credentialsNotRequired,
        SourceAuthorization.missing => l.credentialsMissing,
        SourceAuthorization.configured => l.credentialsUnverified,
        SourceAuthorization.expiring => l.credentialsExpiring,
        SourceAuthorization.expired => l.credentialsExpired,
        SourceAuthorization.rejected => l.credentialsRejected,
        SourceAuthorization.verified => l.credentialsVerified,
      };
}
