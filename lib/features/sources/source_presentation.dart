import '../../data/configuration/source_credential_broker.dart';
import '../../data/sources/source_manager.dart';
import '../../l10n/generated/app_localizations.dart';

/// Host-owned status translations; source services stay independent of Widgets.
abstract final class SourcePresentation {
  static bool needsAttention(
    SourceApplicationStatus application,
    SourceAuthorization authorization,
  ) =>
      application != SourceApplicationStatus.disabled &&
      (application == SourceApplicationStatus.failed ||
          const {
            SourceAuthorization.missing,
            SourceAuthorization.expiring,
            SourceAuthorization.expired,
            SourceAuthorization.rejected,
          }.contains(authorization));

  /// Saved credentials alone must never be presented as a live connection.
  static String summary(
    AppLocalizations l,
    SourceApplicationStatus status,
    SourceAuthorization authorization,
  ) {
    if (status == SourceApplicationStatus.disabled) return l.disabled;
    if (needsAttention(status, authorization)) {
      return status == SourceApplicationStatus.failed
          ? l.sourceConnectionFailed
          : credential(l, authorization);
    }
    return status == SourceApplicationStatus.ready
        ? l.sourceReady
        : l.sourceAwaitingVerification;
  }

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
