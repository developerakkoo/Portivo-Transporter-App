/// Compile-time feature flags (dart-define).
class AppFlags {
  AppFlags._();

  /// When true, app opens [LiveTrackingSandboxScreen] at `/` without login.
  /// Default is false (normal `/splash` auth). Dev: `--dart-define=TRACKING_SANDBOX=true`
  static const bool trackingSandbox = bool.fromEnvironment(
    'TRACKING_SANDBOX',
    defaultValue: false,
  );
}
