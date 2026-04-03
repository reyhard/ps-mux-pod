import 'command_executor.dart';
import 'mux_types.dart';

/// Auto-detects which terminal multiplexer backend is available on the target
/// system.
///
/// Probes psmux first (since its presence implies a local Windows environment),
/// then falls back to tmux.  When neither is conclusively detected, tmux is
/// returned as the most common default.
class MuxDetector {
  MuxDetector(this.executor);

  final CommandExecutor executor;

  /// Auto-detect which multiplexer backend is available.
  ///
  /// Tries psmux first (since it implies local Windows), then tmux.
  /// Returns [MuxType.tmux] as the default when both probes fail.
  Future<MuxType> detect() async {
    // Try psmux -V
    try {
      final output = await executor.execute('psmux -V');
      if (output.isNotEmpty &&
          !output.toLowerCase().contains('not found') &&
          !output.toLowerCase().contains('error')) {
        return MuxType.psmux;
      }
    } catch (_) {}

    // Try tmux -V
    try {
      final output = await executor.execute('tmux -V');
      if (output.isNotEmpty &&
          !output.toLowerCase().contains('not found') &&
          !output.toLowerCase().contains('error')) {
        return MuxType.tmux;
      }
    } catch (_) {}

    // Default to tmux (most common)
    return MuxType.tmux;
  }
}
