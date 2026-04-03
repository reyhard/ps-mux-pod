import 'mux_backend.dart';

/// Tree node representing a multiplexer backend in a nesting hierarchy.
///
/// Example: psmux -> WSL -> tmux forms a chain of MuxNode objects.
/// Full implementation provided by Agent 4 (WslBridgeExecutor + MuxNode).
class MuxNode {
  /// Display label for this node (e.g. "psmux:work", "tmux:dev")
  final String label;

  /// The backend this node wraps
  final MuxBackend backend;

  /// Parent node in the nesting hierarchy (null for root)
  final MuxNode? parent;

  /// Child nodes (nested backends discovered in panes)
  final List<MuxNode> children;

  MuxNode({
    required this.label,
    required this.backend,
    this.parent,
    List<MuxNode>? children,
  }) : children = children ?? [];

  /// Build the breadcrumb path from root to this node
  List<MuxNode> breadcrumbPath() {
    final path = <MuxNode>[];
    MuxNode? current = this;
    while (current != null) {
      path.insert(0, current);
      current = current.parent;
    }
    return path;
  }

  /// Add a child node
  void addChild(MuxNode child) {
    children.add(child);
  }
}
