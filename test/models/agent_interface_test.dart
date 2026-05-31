import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_muxpod/models/agent_interface.dart';

void main() {
  group('AgentInterface', () {
    test('parses known storage values', () {
      expect(agentInterfaceFromStorage('claude'), AgentInterface.claude);
      expect(agentInterfaceFromStorage('codex'), AgentInterface.codex);
    });

    test('falls back to Claude for missing or unknown values', () {
      expect(agentInterfaceFromStorage(null), AgentInterface.claude);
      expect(agentInterfaceFromStorage(''), AgentInterface.claude);
      expect(agentInterfaceFromStorage('other'), AgentInterface.claude);
    });

    test('exposes stable storage values and labels', () {
      expect(AgentInterface.claude.storageValue, 'claude');
      expect(AgentInterface.codex.storageValue, 'codex');
      expect(AgentInterface.claude.displayLabel, 'Claude Code');
      expect(AgentInterface.codex.displayLabel, 'Codex');
    });
  });
}
