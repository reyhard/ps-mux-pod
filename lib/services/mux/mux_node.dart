import 'command_executor.dart';
import 'mux_backend.dart';

/// A node in a tree of nested multiplexer backends.
///
/// Each [MuxNode] pairs a [MuxBackend] with the [CommandExecutor] used to
/// communicate with it. Nodes form a parent–child tree that mirrors the
/// physical nesting: e.g. psmux (root) → WSL bridge → tmux (leaf).
///
/// Example tree:
/// ```
/// root  (PsmuxBackend  / SshExecutor)
///   └─ child  (TmuxBackend  / WslBridgeExecutor, paneTarget: "%1")
///        └─ grandchild  (TmuxBackend  / WslBridgeExecutor, paneTarget: "%0")
/// ```
class MuxNode {
  /// The multiplexer backend for this level of the hierarchy.
  final MuxBackend backend;

  /// The executor used to send commands to [backend].
  final CommandExecutor executor;

  /// The parent node, or `null` if this is the root.
  final MuxNode? parent;

  /// The pane identifier (in the *parent* multiplexer) that hosts this node.
  ///
  /// `null` for the root node.
  final String? paneTarget;

  final List<MuxNode> _children = [];

  MuxNode({
    required this.backend,
    required this.executor,
    this.parent,
    this.paneTarget,
  });

  /// An unmodifiable view of this node's direct children.
  List<MuxNode> get children => List.unmodifiable(_children);

  // ---------------------------------------------------------------------------
  // Tree mutation
  // ---------------------------------------------------------------------------

  /// Appends [child] as a direct child of this node.
  void attachChild(MuxNode child) {
    _children.add(child);
  }

  /// Removes [child] from this node's children list.
  ///
  /// Does nothing if [child] is not a direct child of this node.
  void detachChild(MuxNode child) {
    _children.remove(child);
  }

  // ---------------------------------------------------------------------------
  // Tree traversal helpers
  // ---------------------------------------------------------------------------

  /// Returns the root of the tree that contains this node.
  ///
  /// If this node is already the root, returns `this`.
  MuxNode findRoot() {
    MuxNode current = this;
    while (current.parent != null) {
      current = current.parent!;
    }
    return current;
  }

  /// Returns the ordered list of nodes from the root down to (and including)
  /// this node — the "breadcrumb" path.
  List<MuxNode> breadcrumbPath() {
    final path = <MuxNode>[];
    MuxNode? current = this;
    while (current != null) {
      path.insert(0, current);
      current = current.parent;
    }
    return path;
  }

  // ---------------------------------------------------------------------------
  // Properties
  // ---------------------------------------------------------------------------

  /// How many levels below the root this node sits (root = 0).
  int get depth {
    int d = 0;
    MuxNode? current = parent;
    while (current != null) {
      d++;
      current = current.parent;
    }
    return d;
  }

  /// `true` if this node has no parent (i.e. it is the root of the tree).
  bool get isRoot => parent == null;

  /// `true` if this node has no children.
  bool get isLeaf => _children.isEmpty;
}
