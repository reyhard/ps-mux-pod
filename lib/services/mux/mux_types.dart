/// Backend type for terminal multiplexer.
enum MuxType { tmux, psmux, auto }

/// Transport layer for command execution.
enum TransportType { ssh, local, wslBridge }
