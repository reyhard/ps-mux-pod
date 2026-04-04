/// tmux command generation service
///
/// Utility class for generating tmux commands.
/// Uses format strings compatible with TmuxParser.
class TmuxCommands {
  /// Default delimiter (uses `|||` because tabs can be transformed over SSH)
  static const String delimiter = '|||';

  // ===== Sessions =====

  /// Command to list sessions (detailed)
  ///
  /// Output format: `session_name\tsession_created\tsession_attached\tsession_windows\tsession_id`
  static String listSessions() {
    return 'tmux list-sessions -F "'
        '#{session_name}$delimiter'
        '#{session_created}$delimiter'
        '#{session_attached}$delimiter'
        '#{session_windows}$delimiter'
        '#{session_id}'
        '"';
  }

  /// Command to list sessions (simple)
  ///
  /// Output format: `session_name:session_windows:session_attached`
  static String listSessionsSimple() {
    return 'tmux list-sessions -F "#{session_name}:#{session_windows}:#{session_attached}"';
  }

  /// Check whether a session exists
  static String hasSession(String sessionName) {
    return 'tmux has-session -t ${_escapeArg(sessionName)} 2>/dev/null && echo "1" || echo "0"';
  }

  /// Create a new session
  static String newSession({
    required String name,
    String? windowName,
    String? startDirectory,
    bool detached = true,
  }) {
    final parts = ['tmux', 'new-session'];
    if (detached) parts.add('-d');
    parts.addAll(['-s', _escapeArg(name)]);
    if (windowName != null) parts.addAll(['-n', _escapeArg(windowName)]);
    if (startDirectory != null) parts.addAll(['-c', _escapeArg(startDirectory)]);
    return parts.join(' ');
  }

  /// Delete a session
  static String killSession(String sessionName) {
    return 'tmux kill-session -t ${_escapeArg(sessionName)}';
  }

  /// Rename a session
  static String renameSession(String oldName, String newName) {
    return 'tmux rename-session -t ${_escapeArg(oldName)} ${_escapeArg(newName)}';
  }

  // ===== Windows =====

  /// Command to list windows (detailed)
  ///
  /// Output format: `window_index\twindow_id\twindow_name\twindow_active\twindow_panes\twindow_flags`
  static String listWindows(String sessionName) {
    return 'tmux list-windows -t ${_escapeArg(sessionName)} -F "'
        '#{window_index}$delimiter'
        '#{window_id}$delimiter'
        '#{window_name}$delimiter'
        '#{window_active}$delimiter'
        '#{window_panes}$delimiter'
        '#{window_flags}'
        '"';
  }

  /// Command to list windows (simple)
  ///
  /// Output format: `window_index:window_name:window_active:window_panes`
  static String listWindowsSimple(String sessionName) {
    return 'tmux list-windows -t ${_escapeArg(sessionName)} -F "'
        '#{window_index}:#{window_name}:#{window_active}:#{window_panes}"';
  }

  /// Create a new window
  static String newWindow({
    required String sessionName,
    String? windowName,
    String? startDirectory,
    bool background = false,
  }) {
    final parts = ['tmux', 'new-window', '-t', _escapeArg(sessionName)];
    if (background) parts.add('-d');
    if (windowName != null) parts.addAll(['-n', _escapeArg(windowName)]);
    if (startDirectory != null) parts.addAll(['-c', _escapeArg(startDirectory)]);
    return parts.join(' ');
  }

  /// Select a window
  static String selectWindow(String sessionName, int windowIndex) {
    return 'tmux select-window -t ${_escapeArg(sessionName)}:$windowIndex';
  }

  /// Delete a window
  static String killWindow(String sessionName, int windowIndex) {
    return 'tmux kill-window -t ${_escapeArg(sessionName)}:$windowIndex';
  }

  /// Rename a window
  static String renameWindow(String sessionName, int windowIndex, String newName) {
    return 'tmux rename-window -t ${_escapeArg(sessionName)}:$windowIndex ${_escapeArg(newName)}';
  }

  // ===== Panes =====

  /// Command to list panes (detailed)
  ///
  /// Output format: `pane_index\tpane_id\tpane_active\tpane_current_command\tpane_title\tpane_width\tpane_height\tcursor_x\tcursor_y`
  static String listPanes(String sessionName, int windowIndex) {
    return 'tmux list-panes -t ${_escapeArg(sessionName)}:$windowIndex -F "'
        '#{pane_index}$delimiter'
        '#{pane_id}$delimiter'
        '#{pane_active}$delimiter'
        '#{pane_current_command}$delimiter'
        '#{pane_title}$delimiter'
        '#{pane_width}$delimiter'
        '#{pane_height}$delimiter'
        '#{cursor_x}$delimiter'
        '#{cursor_y}'
        '"';
  }

  /// Command to list panes (simple)
  ///
  /// Output format: `pane_index:pane_id:pane_active:pane_width x pane_height`
  static String listPanesSimple(String sessionName, int windowIndex) {
    return 'tmux list-panes -t ${_escapeArg(sessionName)}:$windowIndex -F "'
        '#{pane_index}:#{pane_id}:#{pane_active}:#{pane_width}x#{pane_height}"';
  }

  /// Command to list all panes (for session tree construction)
  ///
  /// Output format: complete tree information (including window_flags)
  static String listAllPanes() {
    return 'tmux list-panes -a -F "'
        '#{session_name}$delimiter'
        '#{session_id}$delimiter'
        '#{window_index}$delimiter'
        '#{window_id}$delimiter'
        '#{window_name}$delimiter'
        '#{window_active}$delimiter'
        '#{pane_index}$delimiter'
        '#{pane_id}$delimiter'
        '#{pane_active}$delimiter'
        '#{pane_width}$delimiter'
        '#{pane_height}$delimiter'
        '#{pane_left}$delimiter'
        '#{pane_top}$delimiter'
        '#{pane_title}$delimiter'
        '#{pane_current_command}$delimiter'
        '#{cursor_x}$delimiter'
        '#{cursor_y}$delimiter'
        '#{window_flags}'
        '"';
  }

  /// Select a pane
  static String selectPane(String paneId) {
    return 'tmux select-pane -t ${_escapeArg(paneId)}';
  }

  /// Split pane horizontally
  static String splitWindowHorizontal({
    required String target,
    String? startDirectory,
    int? percentage,
  }) {
    final parts = ['tmux', 'split-window', '-h', '-t', _escapeArg(target)];
    if (percentage != null) parts.addAll(['-p', percentage.toString()]);
    if (startDirectory != null) parts.addAll(['-c', _escapeArg(startDirectory)]);
    return parts.join(' ');
  }

  /// Split pane vertically
  static String splitWindowVertical({
    required String target,
    String? startDirectory,
    int? percentage,
  }) {
    final parts = ['tmux', 'split-window', '-v', '-t', _escapeArg(target)];
    if (percentage != null) parts.addAll(['-p', percentage.toString()]);
    if (startDirectory != null) parts.addAll(['-c', _escapeArg(startDirectory)]);
    return parts.join(' ');
  }

  /// Delete a pane
  static String killPane(String paneId) {
    return 'tmux kill-pane -t ${_escapeArg(paneId)}';
  }

  /// Zoom/unzoom a pane
  static String resizePane(String paneId, {bool zoom = true}) {
    return 'tmux resize-pane -t ${_escapeArg(paneId)} ${zoom ? '-Z' : '-z'}';
  }

  // ===== Input and key sending =====

  /// Send keys
  static String sendKeys(String paneId, String keys, {bool literal = false}) {
    final escapedKeys = _escapeArg(keys);
    if (literal) {
      return 'tmux send-keys -t ${_escapeArg(paneId)} -l $escapedKeys';
    }
    return 'tmux send-keys -t ${_escapeArg(paneId)} $escapedKeys';
  }

  /// Send the Enter key
  static String sendEnter(String paneId) {
    return 'tmux send-keys -t ${_escapeArg(paneId)} Enter';
  }

  /// Send Ctrl+C
  static String sendInterrupt(String paneId) {
    return 'tmux send-keys -t ${_escapeArg(paneId)} C-c';
  }

  /// Send the Escape key
  static String sendEscape(String paneId) {
    return 'tmux send-keys -t ${_escapeArg(paneId)} Escape';
  }

  /// Get the cursor position and pane size
  static String getCursorPosition(String target) {
    return 'tmux display-message -p -t ${_escapeArg(target)} "#{cursor_x},#{cursor_y},#{pane_width},#{pane_height}"';
  }

  /// Get the pane mode (for copy-mode detection)
  static String getPaneMode(String target) {
    return 'tmux display-message -p -t ${_escapeArg(target)} "#{pane_mode}"';
  }

  /// Get cursor position, pane size, and pane mode in one call (for polling optimization)
  ///
  /// Output format: cursor_x,cursor_y,pane_width,pane_height,pane_mode
  /// pane_mode is set only in copy-mode (empty string otherwise)
  static String getPaneInfo(String target) {
    return "tmux display-message -p -t ${_escapeArg(target)} '#{cursor_x},#{cursor_y},#{pane_width},#{pane_height},#{pane_mode}'";
  }

  /// Enter copy-mode
  static String enterCopyMode(String target) {
    return 'tmux copy-mode -t ${_escapeArg(target)}';
  }

  /// Exit copy-mode (only effective in copy-mode, harmless otherwise)
  static String cancelCopyMode(String target) {
    return 'tmux send-keys -t ${_escapeArg(target)} -X cancel';
  }

  // ===== Pane content =====

  /// Capture pane content (with ANSI escapes)
  static String capturePane(
    String paneId, {
    int? startLine,
    int? endLine,
    bool escapeSequences = true,
  }) {
    final parts = ['tmux', 'capture-pane', '-t', _escapeArg(paneId), '-p'];
    if (escapeSequences) parts.add('-e');
    if (startLine != null) parts.addAll(['-S', startLine.toString()]);
    if (endLine != null) parts.addAll(['-E', endLine.toString()]);
    return parts.join(' ');
  }

  /// Capture the visible pane area
  static String capturePaneVisible(String paneId) {
    return capturePane(paneId, escapeSequences: true);
  }

  /// Capture the full pane scrollback
  static String capturePaneAll(String paneId) {
    return capturePane(paneId, startLine: -32768, endLine: 32768);
  }

  // ===== Session/attach =====

  /// Attach to a session
  static String attachSession(String sessionName) {
    return 'tmux attach-session -t ${_escapeArg(sessionName)}';
  }

  /// Detach the client
  static String detachClient({String? sessionName}) {
    if (sessionName != null) {
      return 'tmux detach-client -s ${_escapeArg(sessionName)}';
    }
    return 'tmux detach-client';
  }

  // ===== Server =====

  /// Check whether the tmux server is running
  static String serverInfo() {
    return 'tmux server-info 2>&1';
  }

  /// Get the tmux version
  static String version() {
    return 'tmux -V';
  }

  /// Start the tmux server
  static String startServer() {
    return 'tmux start-server';
  }

  /// Stop the tmux server
  static String killServer() {
    return 'tmux kill-server';
  }

  // ===== Layout =====

  /// Apply a predefined layout
  static String selectLayout(String target, TmuxLayout layout) {
    return 'tmux select-layout -t ${_escapeArg(target)} ${layout.name}';
  }

  // ===== Utilities =====

  /// Escape an argument
  static String _escapeArg(String arg) {
    // Escape shell special characters
    // Special characters: spaces, quotes, backslashes, variable expansion, backticks, and others
    if (arg.contains(RegExp(r'[\s"' "'" r'\\$`!{}\[\]<>|&;()]'))) {
      // Wrap in double quotes and escape special characters inside
      final escaped = arg
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll(r'$', r'\$')
          .replaceAll('`', r'\`');
      return '"$escaped"';
    }
    return arg;
  }

  /// Chain multiple commands
  static String chain(List<String> commands) {
    return commands.join(' && ');
  }

  /// Pipe multiple commands together
  static String pipe(List<String> commands) {
    return commands.join(' | ');
  }
}

/// Pane split direction
enum SplitDirection {
  /// Split to the right (side-by-side) - tmux split-window -h
  horizontal,

  /// Split downward (stacked vertically) - tmux split-window -v
  vertical,
}

/// tmux layout
enum TmuxLayout {
  /// Even horizontal split
  evenHorizontal,

  /// Even vertical split
  evenVertical,

  /// Place the main pane on top
  mainHorizontal,

  /// Place the main pane on the left
  mainVertical,

  /// Tile layout
  tiled,
}

extension TmuxLayoutExtension on TmuxLayout {
  String get name {
    switch (this) {
      case TmuxLayout.evenHorizontal:
        return 'even-horizontal';
      case TmuxLayout.evenVertical:
        return 'even-vertical';
      case TmuxLayout.mainHorizontal:
        return 'main-horizontal';
      case TmuxLayout.mainVertical:
        return 'main-vertical';
      case TmuxLayout.tiled:
        return 'tiled';
    }
  }
}
