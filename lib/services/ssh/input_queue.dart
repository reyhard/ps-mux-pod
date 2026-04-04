/// Queues input while disconnected.
///
/// Keeps key input while the SSH connection is disconnected so it can be
/// sent in a batch after reconnection.
class InputQueue {
  final List<String> _queue = [];

  /// Maximum queue size (characters)
  static const int maxSize = 1000;

  /// Add input to the queue
  ///
  /// If adding the input would exceed maxSize, it is dropped and isOverflow becomes true.
  void enqueue(String input) {
    if (length + input.length <= maxSize) {
      _queue.add(input);
    }
  }

  /// Remove and join all input in the queue
  ///
  /// The queue is empty after flushing.
  String flush() {
    if (_queue.isEmpty) return '';
    final result = _queue.join();
    _queue.clear();
    return result;
  }

  /// Clear the queue
  void clear() {
    _queue.clear();
  }

  /// Whether the queue is empty
  bool get isEmpty => _queue.isEmpty;

  /// Total number of characters in the queue
  int get length {
    int total = 0;
    for (final item in _queue) {
      total += item.length;
    }
    return total;
  }

  /// Whether the queue is overflowed and can no longer accept input
  bool get isOverflow => length >= maxSize;

  /// Number of items in the queue
  int get itemCount => _queue.length;
}
