import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/mux/command_executor.dart';
import 'package:flutter_muxpod/services/mux/mux_detector.dart';
import 'package:flutter_muxpod/services/mux/mux_types.dart';

/// A [CommandExecutor] whose response per command is driven by a lookup map.
///
/// Keys are exact command strings; values are either a [String] to return or
/// an [Exception] to throw.
class _MapExecutor implements CommandExecutor {
  _MapExecutor(this._responses);

  final Map<String, Object> _responses; // String | Exception

  @override
  Future<String> execute(String command) async {
    final entry = _responses[command];
    if (entry == null) return '';
    if (entry is Exception) throw entry;
    return entry as String;
  }

  @override
  Future<InteractiveShell> openInteractiveShell({int cols = 80, int rows = 24}) {
    throw UnimplementedError('Not needed for detector tests');
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('MuxDetector', () {
    test('returns MuxType.psmux when psmux -V succeeds', () async {
      final executor = _MapExecutor({
        'psmux -V': 'psmux 0.3.1',
        'tmux -V': 'tmux 3.3a',
      });
      final detector = MuxDetector(executor);
      expect(await detector.detect(), equals(MuxType.psmux));
    });

    test('returns MuxType.tmux when only tmux -V succeeds', () async {
      final executor = _MapExecutor({
        'psmux -V': Exception('command not found'),
        'tmux -V': 'tmux 3.3a',
      });
      final detector = MuxDetector(executor);
      expect(await detector.detect(), equals(MuxType.tmux));
    });

    test('returns MuxType.tmux when psmux outputs "not found"', () async {
      final executor = _MapExecutor({
        'psmux -V': 'psmux: command not found',
        'tmux -V': 'tmux 3.3a',
      });
      final detector = MuxDetector(executor);
      expect(await detector.detect(), equals(MuxType.tmux));
    });

    test('returns MuxType.tmux when psmux output contains "error"', () async {
      final executor = _MapExecutor({
        'psmux -V': 'error: psmux not available',
        'tmux -V': 'tmux 3.3a',
      });
      final detector = MuxDetector(executor);
      expect(await detector.detect(), equals(MuxType.tmux));
    });

    test('returns MuxType.tmux (default) when both probes fail with exception',
        () async {
      final executor = _MapExecutor({
        'psmux -V': Exception('not found'),
        'tmux -V': Exception('not found'),
      });
      final detector = MuxDetector(executor);
      expect(await detector.detect(), equals(MuxType.tmux));
    });

    test('returns MuxType.tmux (default) when both return empty string',
        () async {
      final executor = _MapExecutor({});
      final detector = MuxDetector(executor);
      expect(await detector.detect(), equals(MuxType.tmux));
    });

    test('returns MuxType.tmux (default) when both output "not found"',
        () async {
      final executor = _MapExecutor({
        'psmux -V': 'psmux: command not found',
        'tmux -V': 'tmux: command not found',
      });
      final detector = MuxDetector(executor);
      expect(await detector.detect(), equals(MuxType.tmux));
    });

    test('probes psmux before tmux', () async {
      final probeOrder = <String>[];
      final executor = _MapExecutor({
        'psmux -V': 'psmux 1.0',
      });
      // Wrap executor to capture probe order.
      final trackingExecutor = _TrackingExecutor(executor, probeOrder);
      final detector = MuxDetector(trackingExecutor);
      await detector.detect();

      expect(probeOrder.first, equals('psmux -V'));
    });
  });
}

/// Wraps a [CommandExecutor] and records every executed command in [log].
class _TrackingExecutor implements CommandExecutor {
  _TrackingExecutor(this._inner, this.log);

  final CommandExecutor _inner;
  final List<String> log;

  @override
  Future<String> execute(String command) {
    log.add(command);
    return _inner.execute(command);
  }

  @override
  Future<InteractiveShell> openInteractiveShell({int cols = 80, int rows = 24}) {
    return _inner.openInteractiveShell(cols: cols, rows: rows);
  }

  @override
  Future<void> dispose() => _inner.dispose();
}
