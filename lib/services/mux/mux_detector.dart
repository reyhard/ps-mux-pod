import 'package:flutter/foundation.dart';

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
      debugPrint('[MuxDetector] Probing psmux -V ...');
      final output = await executor.execute('psmux -V');
      debugPrint('[MuxDetector] psmux -V output: "$output"');
      if (output.isNotEmpty &&
          !output.toLowerCase().contains('not found') &&
          !output.toLowerCase().contains('error')) {
        debugPrint('[MuxDetector] psmux detected');
        return MuxType.psmux;
      }
    } catch (e) {
      debugPrint('[MuxDetector] psmux -V failed: $e');
    }

    // Try tmux -V
    try {
      debugPrint('[MuxDetector] Probing tmux -V ...');
      final output = await executor.execute('tmux -V');
      debugPrint('[MuxDetector] tmux -V output: "$output"');
      if (output.isNotEmpty &&
          !output.toLowerCase().contains('not found') &&
          !output.toLowerCase().contains('error')) {
        debugPrint('[MuxDetector] tmux detected');
        return MuxType.tmux;
      }
    } catch (e) {
      debugPrint('[MuxDetector] tmux -V failed: $e');
    }

    // Default to tmux (most common)
    debugPrint('[MuxDetector] Neither detected, defaulting to tmux');
    return MuxType.tmux;
  }
}
