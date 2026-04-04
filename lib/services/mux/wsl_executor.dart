import 'command_executor.dart';

/// Wraps a [CommandExecutor] to forward commands through WSL.
///
/// Every [execute] call is prefixed with `wsl -d <distro> --` so that
/// the underlying executor (e.g. an SSH session into a Windows host)
/// transparently runs the command inside the specified WSL distribution.
///
/// [openInteractiveShell] and [dispose] are deliberately delegated or no-op'd:
/// - [openInteractiveShell] opens an interactive session via the inner executor;
///   the caller is expected to drive WSL interaction through that session.
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
  /// The returned [InteractiveShell] provides bidirectional I/O; it is
  /// the caller's responsibility to send WSL commands through it.
  @override
  Future<InteractiveShell> openInteractiveShell({int cols = 80, int rows = 24}) {
    return _inner.openInteractiveShell(cols: cols, rows: rows);
  }

  /// No-op — the inner executor's lifetime is managed by its creator.
  @override
  Future<void> dispose() async {
    // Intentionally does not dispose _inner.
  }
}
