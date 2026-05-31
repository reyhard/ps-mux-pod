import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/models/agent_interface.dart';
import 'package:flutter_muxpod/providers/connection_provider.dart';

void main() {
  group('Connection agentInterface persistence', () {
    test('defaults missing agentInterface to Claude', () {
      final connection = Connection.fromJson({
        'id': 'conn-1',
        'name': 'Production',
        'host': 'example.com',
        'port': 22,
        'username': 'deploy',
        'authMethod': 'password',
        'createdAt': DateTime(2026, 5, 31).toIso8601String(),
      });

      expect(connection.agentInterface, AgentInterface.claude);
    });

    test('falls back to Claude for unknown agentInterface values', () {
      final connection = Connection.fromJson({
        'id': 'conn-1',
        'name': 'Production',
        'host': 'example.com',
        'port': 22,
        'username': 'deploy',
        'authMethod': 'password',
        'createdAt': DateTime(2026, 5, 31).toIso8601String(),
        'agentInterface': 'unsupported',
      });

      expect(connection.agentInterface, AgentInterface.claude);
    });

    test('persists Codex agentInterface to JSON', () {
      final connection = Connection(
        id: 'conn-1',
        name: 'Production',
        host: 'example.com',
        username: 'deploy',
        createdAt: DateTime(2026, 5, 31),
        agentInterface: AgentInterface.codex,
      );

      expect(connection.toJson()['agentInterface'], 'codex');
    });

    test('copyWith can update agentInterface', () {
      final connection = Connection(
        id: 'conn-1',
        name: 'Production',
        host: 'example.com',
        username: 'deploy',
        createdAt: DateTime(2026, 5, 31),
      );

      final updated = connection.copyWith(agentInterface: AgentInterface.codex);

      expect(connection.agentInterface, AgentInterface.claude);
      expect(updated.agentInterface, AgentInterface.codex);
    });
  });
}
