import '../../../l10n/generated/app_localizations.dart';

String aiFailureMessage(String code, AppLocalizations l) => switch (code) {
  'configurationRequired' => l.aiConfigureFirst,
  'cancelled' => l.aiCancelled,
  'interrupted' => l.aiInterrupted,
  'authenticationFailed' => l.aiAuthenticationFailed,
  'rateLimited' => l.aiRateLimited,
  'protocolMismatch' => l.aiProtocolMismatch,
  'turnTimeout' || 'requestTimeout' => l.aiTimeout,
  'requestBudget' ||
  'toolBudget' ||
  'tokenBudget' ||
  'outputLimit' ||
  'contextBudget' => l.aiBudgetReached,
  _ => l.aiProviderFailed,
};
