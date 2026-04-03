import 'command_executor.dart';

/// Wraps a [CommandExecutor] to forward commands through WSL.
///
/// Every [execute] call is prefixed with `wsl -d <distro> --` so that
/// the underlying executor (e.g. an SSH session into a Windows host)
/// transparently runs the command inside the specified WSL distribution.
///
/// [shell] and [dispose] are deliberately delegated or no-op'd:
/// - [shell] opens an interactive session via the inner executor; the
///   caller is expected to drive WSL interaction through that session.
/// - [dispose] does **not** dispose the inner executor — lifetime of the
///   inner executor is the caller's responsibility.
class WslBridgeExecutor implements CommandExecutor {
  final CommandExecutor _inner;

  /// The WSL distribution name (e.g. `"Ubuntu"`, `"Debian"`).
  final String distro;

  WslBridgeExecutor(this._inner, {required this.distro});

  /// Wraps [command] as `wsl -d <distro> -- <command>` and delegates
  /// to the inner executor.
  @override
  Future<String> execute(String command) {
    return _inner.execute('wsl -d $distro -- $command');
  }

  /// Opens an interactive shell via the inner executor.
  ///
  /// The returned byte stream is the raw I/O of the inner shell; it is
  /// the caller's responsibility to send WSL commands through it.
  @override
  Future<Stream<List<int>>> shell() {
    return _inner.shell();
  }

  /// No-op — the inner executor's lifetime is managed by its creator.
  @override
  Future<void> dispose() async {
    // Intentionally does not dispose _inner.
  }
}
