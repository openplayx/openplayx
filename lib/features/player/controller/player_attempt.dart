/// Runs a player adjustment and reports whether it succeeded. The view
/// supplies it and shows a failure to the user, so controllers stay free
/// of UI code.
typedef PlayerAttempt = Future<bool> Function(Future<void> Function() action);

/// Runs a playback command (play, pause, seek, open); a failure puts the
/// player into its error state.
typedef PlayerCommand = Future<void> Function(Future<void> Function() action);
