import 'dart:typed_data';

/// Bidirectional PTY session for real-time terminal I/O.
class MuxPtySession {
  MuxPtySession({
    required this.stdout,
    required this.write,
    required this.resize,
    required this.close,
  });

  final Stream<List<int>> stdout;
  final void Function(Uint8List data) write;
  final void Function(int cols, int rows) resize;
  final Future<void> Function() close;
}
