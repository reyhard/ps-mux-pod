/// Provides build-time injected version information.
///
/// Priority:
/// 1. APP_VERSION (set from the release tag in CI)
/// 2. GIT_REF (branch name @ commit hash)
/// 3. 'UNKNOWN'
class VersionInfo {
  static const String _appVersion = String.fromEnvironment('APP_VERSION');
  static const String _gitRef = String.fromEnvironment('GIT_REF');

  static String get version {
    if (_appVersion.isNotEmpty) return _appVersion;
    if (_gitRef.isNotEmpty) return _gitRef;
    return 'UNKNOWN';
  }
}
