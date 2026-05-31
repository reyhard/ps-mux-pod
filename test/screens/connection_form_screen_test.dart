import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/models/agent_interface.dart';
import 'package:flutter_muxpod/providers/connection_provider.dart';
import 'package:flutter_muxpod/screens/connections/connection_form_screen.dart';

class _FakeConnectionsNotifier extends ConnectionsNotifier {
  _FakeConnectionsNotifier(this.initialConnections);

  final List<Connection> initialConnections;
  Connection? addedConnection;
  Connection? updatedConnection;

  @override
  ConnectionsState build() {
    return ConnectionsState(connections: initialConnections);
  }

  @override
  Connection? getById(String id) {
    for (final connection in state.connections) {
      if (connection.id == id) {
        return connection;
      }
    }
    return null;
  }

  @override
  Future<void> add(Connection connection) async {
    addedConnection = connection;
    state = state.copyWith(connections: [...state.connections, connection]);
  }

  @override
  Future<void> update(Connection connection) async {
    updatedConnection = connection;
    state = state.copyWith(
      connections: [
        for (final existing in state.connections)
          if (existing.id == connection.id) connection else existing,
      ],
    );
  }
}

void main() {
  Widget buildForm({
    required _FakeConnectionsNotifier notifier,
    String? connectionId,
  }) {
    return ProviderScope(
      overrides: [
        connectionsProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        home: ConnectionFormScreen(connectionId: connectionId),
      ),
    );
  }

  group('ConnectionFormScreen agent interface', () {
    testWidgets('shows Agent Interface with Claude default', (tester) async {
      final notifier = _FakeConnectionsNotifier([]);

      await tester.pumpWidget(buildForm(notifier: notifier));
      await tester.pumpAndSettle();

      expect(find.text('AGENT INTERFACE'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Codex'), findsNothing);
    });

    testWidgets('loads Codex for an existing connection', (tester) async {
      final notifier = _FakeConnectionsNotifier([
        Connection(
          id: 'conn-1',
          name: 'Production',
          host: 'example.com',
          username: 'deploy',
          createdAt: DateTime(2026, 5, 31),
          agentInterface: AgentInterface.codex,
        ),
      ]);

      await tester.pumpWidget(
        buildForm(notifier: notifier, connectionId: 'conn-1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Connection'), findsOneWidget);
      expect(find.text('AGENT INTERFACE'), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
    });

    testWidgets('saves changed agent interface on edit', (tester) async {
      final notifier = _FakeConnectionsNotifier([
        Connection(
          id: 'conn-1',
          name: 'Production',
          host: 'example.com',
          username: 'deploy',
          createdAt: DateTime(2026, 5, 31),
        ),
      ]);

      await tester.pumpWidget(
        buildForm(notifier: notifier, connectionId: 'conn-1'),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Claude Code'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Claude Code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(notifier.updatedConnection, isNotNull);
      expect(notifier.updatedConnection!.agentInterface, AgentInterface.codex);
    });
  });
}
