/// Unified session model for any multiplexer backend.
class MuxSession {
  final String id;
  final String name;
  final DateTime? created;
  final bool attached;
  final int windowCount;
  final List<MuxWindow> windows;

  const MuxSession({
    required this.id,
    required this.name,
    this.created,
    this.attached = false,
    this.windowCount = 0,
    this.windows = const [],
  });
}

/// Unified window model for any multiplexer backend.
class MuxWindow {
  final int index;
  final String id;
  final String name;
  final bool active;
  final int paneCount;
  final List<MuxPane> panes;

  const MuxWindow({
    required this.index,
    required this.id,
    required this.name,
    this.active = false,
    this.paneCount = 0,
    this.panes = const [],
  });
}

/// Unified pane model for any multiplexer backend.
class MuxPane {
  final int index;
  final String id;
  final bool active;
  final String? currentCommand;
  final int width;
  final int height;

  const MuxPane({
    required this.index,
    required this.id,
    this.active = false,
    this.currentCommand,
    this.width = 0,
    this.height = 0,
  });
}
