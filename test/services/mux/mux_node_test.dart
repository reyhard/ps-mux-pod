import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/services/mux/command_executor.dart';
import 'package:flutter_muxpod/services/mux/mux_backend.dart';
import 'package:flutter_muxpod/services/mux/mux_models.dart';
import 'package:flutter_muxpod/services/mux/mux_node.dart';
import 'package:flutter_muxpod/services/mux/mux_pty_session.dart';

// ---------------------------------------------------------------------------
// Manual mocks
// ---------------------------------------------------------------------------

class _MockCommandExecutor implements CommandExecutor {
  @override
  Future<String> execute(String command) async => '';

  @override
  Future<InteractiveShell> openInteractiveShell({int cols = 80, int rows = 24}) {
    throw UnimplementedError('Not needed for node tests');
  }

  @override
  Future<void> dispose() async {}
}

class _MockMuxBackend implements MuxBackend {
  final String _name;
  _MockMuxBackend(this._name);

  @override
  String get name => _name;

  @override
  Future<List<MuxSession>> listSessions() async => [];

  @override
  Future<MuxSession> newSession({String? name}) async =>
      const MuxSession(id: 'id', name: 'name');

  @override
  Future<void> killSession(String sessionId) async {}

  @override
  Future<void> attachSession(String sessionId) async {}

  @override
  Future<List<MuxWindow>> listWindows(String sessionId) async => [];

  @override
  Future<MuxWindow> newWindow(String sessionId, {String? name}) async =>
      const MuxWindow(index: 0, id: 'id', name: 'name');

  @override
  Future<void> selectWindow(String sessionId, int index) async {}

  @override
  Future<List<MuxPane>> listPanes(String windowTarget) async => [];

  @override
  Future<void> splitPane(String target, {bool horizontal = true}) async {}

  @override
  Future<void> selectPane(String target, int index) async {}

  @override
  Future<String> capturePane(String target) async => '';

  @override
  Future<void> sendKeys(String target, String keys) async {}

  @override
  Future<MuxBackend?> getNestedBackend(String paneTarget) async => null;

  @override
  Future<MuxPtySession> attachPty(String sessionId) {
    throw UnimplementedError('Not needed for node tests');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MuxNode _makeNode(String backendName, {MuxNode? parent, String? paneTarget}) {
  return MuxNode(
    backend: _MockMuxBackend(backendName),
    executor: _MockCommandExecutor(),
    parent: parent,
    paneTarget: paneTarget,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MuxNode', () {
    // -----------------------------------------------------------------------
    // Construction & basic properties
    // -----------------------------------------------------------------------

    group('construction', () {
      test('root node has no parent and no children', () {
        final root = _makeNode('psmux');

        expect(root.parent, isNull);
        expect(root.children, isEmpty);
        expect(root.paneTarget, isNull);
      });

      test('stores backend, executor, parent and paneTarget', () {
        final root = _makeNode('psmux');
        final child = _makeNode('tmux', parent: root, paneTarget: '%1');

        expect(child.backend.name, equals('tmux'));
        expect(child.parent, same(root));
        expect(child.paneTarget, equals('%1'));
      });
    });

    // -----------------------------------------------------------------------
    // Tree construction via attachChild / detachChild
    // -----------------------------------------------------------------------

    group('attachChild() / detachChild()', () {
      test('attachChild() adds node to children list', () {
        final root = _makeNode('root');
        final child = _makeNode('child', parent: root);

        root.attachChild(child);

        expect(root.children, hasLength(1));
        expect(root.children.first, same(child));
      });

      test('can attach multiple children', () {
        final root = _makeNode('root');
        final child1 = _makeNode('c1', parent: root);
        final child2 = _makeNode('c2', parent: root);

        root.attachChild(child1);
        root.attachChild(child2);

        expect(root.children, hasLength(2));
      });

      test('detachChild() removes the child', () {
        final root = _makeNode('root');
        final child = _makeNode('child', parent: root);
        root.attachChild(child);

        root.detachChild(child);

        expect(root.children, isEmpty);
      });

      test('detachChild() on non-child is a no-op', () {
        final root = _makeNode('root');
        final unrelated = _makeNode('unrelated');

        // Should not throw.
        root.detachChild(unrelated);
        expect(root.children, isEmpty);
      });

      test('children list is unmodifiable', () {
        final root = _makeNode('root');

        expect(
          () => root.children.add(_makeNode('x')),
          throwsUnsupportedError,
        );
      });
    });

    // -----------------------------------------------------------------------
    // Three-level tree: root → child → grandchild
    // -----------------------------------------------------------------------

    late MuxNode root;
    late MuxNode child;
    late MuxNode grandchild;

    setUp(() {
      root = _makeNode('psmux');
      child = _makeNode('tmux', parent: root, paneTarget: '%1');
      grandchild = _makeNode('tmux-inner', parent: child, paneTarget: '%0');

      root.attachChild(child);
      child.attachChild(grandchild);
    });

    group('findRoot()', () {
      test('findRoot() from root returns itself', () {
        expect(root.findRoot(), same(root));
      });

      test('findRoot() from child returns root', () {
        expect(child.findRoot(), same(root));
      });

      test('findRoot() from grandchild returns root', () {
        expect(grandchild.findRoot(), same(root));
      });
    });

    group('breadcrumbPath()', () {
      test('breadcrumbPath() from root returns [root]', () {
        final path = root.breadcrumbPath();
        expect(path, hasLength(1));
        expect(path[0], same(root));
      });

      test('breadcrumbPath() from child returns [root, child]', () {
        final path = child.breadcrumbPath();
        expect(path, hasLength(2));
        expect(path[0], same(root));
        expect(path[1], same(child));
      });

      test('breadcrumbPath() from grandchild returns [root, child, grandchild]', () {
        final path = grandchild.breadcrumbPath();
        expect(path, hasLength(3));
        expect(path[0], same(root));
        expect(path[1], same(child));
        expect(path[2], same(grandchild));
      });
    });

    group('depth', () {
      test('root depth is 0', () {
        expect(root.depth, equals(0));
      });

      test('child depth is 1', () {
        expect(child.depth, equals(1));
      });

      test('grandchild depth is 2', () {
        expect(grandchild.depth, equals(2));
      });
    });

    group('isRoot', () {
      test('root.isRoot is true', () {
        expect(root.isRoot, isTrue);
      });

      test('child.isRoot is false', () {
        expect(child.isRoot, isFalse);
      });

      test('grandchild.isRoot is false', () {
        expect(grandchild.isRoot, isFalse);
      });
    });

    group('isLeaf', () {
      test('root is not a leaf (has children)', () {
        expect(root.isLeaf, isFalse);
      });

      test('child is not a leaf (has grandchild)', () {
        expect(child.isLeaf, isFalse);
      });

      test('grandchild is a leaf (no children)', () {
        expect(grandchild.isLeaf, isTrue);
      });

      test('standalone node with no children is a leaf', () {
        final lone = _makeNode('lone');
        expect(lone.isLeaf, isTrue);
      });

      test('becomes a non-leaf after attaching a child', () {
        final node = _makeNode('node');
        expect(node.isLeaf, isTrue);

        node.attachChild(_makeNode('sub', parent: node));
        expect(node.isLeaf, isFalse);
      });

      test('becomes a leaf again after detaching all children', () {
        final node = _makeNode('node');
        final sub = _makeNode('sub', parent: node);
        node.attachChild(sub);

        node.detachChild(sub);
        expect(node.isLeaf, isTrue);
      });
    });
  });
}
