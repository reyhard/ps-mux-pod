import 'dart:collection';

/// Client-side scrollback ring buffer for terminal history.
///
/// Accumulates lines that scroll off the top of the visible pane,
/// allowing instant local scrollback without SSH round-trips.
class ScrollbackBuffer {
  final int maxLines;
  final Queue<String> _lines = Queue<String>();
  List<String> _previousVisible = [];

  ScrollbackBuffer({this.maxLines = 10000});

  int get lineCount => _lines.length;

  void appendNewContent(List<String> currentVisible) {
    if (_previousVisible.isEmpty) {
      _previousVisible = List.of(currentVisible);
      return;
    }

    final scrolledOff = _findScrolledOffLines(_previousVisible, currentVisible);

    for (final line in scrolledOff) {
      _lines.addLast(line);
      _evictIfNeeded();
    }

    _previousVisible = List.of(currentVisible);
  }

  List<String> _findScrolledOffLines(List<String> previous, List<String> current) {
    if (previous.isEmpty || current.isEmpty) return previous;

    final firstCurrentLine = current.first;
    int overlapStart = -1;

    for (int i = 0; i < previous.length; i++) {
      if (previous[i] == firstCurrentLine) {
        bool isMatch = true;
        final overlapLen = previous.length - i;
        final checkLen = overlapLen < current.length ? overlapLen : current.length;
        for (int j = 1; j < checkLen; j++) {
          if (previous[i + j] != current[j]) {
            isMatch = false;
            break;
          }
        }
        if (isMatch) {
          overlapStart = i;
          break;
        }
      }
    }

    if (overlapStart <= 0) {
      if (overlapStart == -1) {
        return List.of(previous);
      }
      return [];
    }

    return previous.sublist(0, overlapStart);
  }

  void seedHistory(List<String> lines) {
    _lines.clear();
    for (final line in lines) {
      _lines.addLast(line);
    }
    while (_lines.length > maxLines) {
      _lines.removeFirst();
    }
  }

  List<String> getRange(int start, int end) {
    if (start >= _lines.length) return [];
    final clampedEnd = end > _lines.length ? _lines.length : end;
    final clampedStart = start < 0 ? 0 : start;
    if (clampedStart >= clampedEnd) return [];
    return _lines.toList().sublist(clampedStart, clampedEnd);
  }

  List<String> getAllLines(List<String> currentVisible) {
    return [..._lines, ...currentVisible];
  }

  void clear() {
    _lines.clear();
    _previousVisible = [];
  }

  void _evictIfNeeded() {
    while (_lines.length > maxLines) {
      _lines.removeFirst();
    }
  }
}
