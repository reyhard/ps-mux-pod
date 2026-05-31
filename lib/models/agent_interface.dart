enum AgentInterface {
  claude,
  codex,
}

extension AgentInterfaceLabels on AgentInterface {
  String get storageValue {
    switch (this) {
      case AgentInterface.claude:
        return 'claude';
      case AgentInterface.codex:
        return 'codex';
    }
  }

  String get displayLabel {
    switch (this) {
      case AgentInterface.claude:
        return 'Claude Code';
      case AgentInterface.codex:
        return 'Codex';
    }
  }
}

AgentInterface agentInterfaceFromStorage(String? value) {
  switch (value) {
    case 'codex':
      return AgentInterface.codex;
    case 'claude':
    default:
      return AgentInterface.claude;
  }
}
