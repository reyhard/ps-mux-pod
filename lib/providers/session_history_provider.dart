import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_session_provider.dart';

/// Provider for session history sorted by last access time
/// Sort by lastAccessedAt descending (newest first)
final sessionHistoryProvider = Provider<List<ActiveSession>>((ref) {
  final state = ref.watch(activeSessionsProvider);

  final sorted = [...state.sessions]..sort((a, b) {
    // Fall back to connectedAt if lastAccessedAt is missing
    final aTime = a.lastAccessedAt ?? a.connectedAt;
    final bTime = b.lastAccessedAt ?? b.connectedAt;
    return bTime.compareTo(aTime); // descending
  });

  return sorted;
});
