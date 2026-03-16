enum ConnectionState {
  connecting,
  connected,
  stale,
  disconnected,
}

class ConnectionStatus {
  final ConnectionState state;
  final int? latencyMs;
  final DateTime? lastMessageAt;

  const ConnectionStatus({
    required this.state,
    this.latencyMs,
    this.lastMessageAt,
  });

  factory ConnectionStatus.connecting() => const ConnectionStatus(state: ConnectionState.connecting);

  factory ConnectionStatus.disconnected({DateTime? lastMessageAt}) {
    return ConnectionStatus(state: ConnectionState.disconnected, lastMessageAt: lastMessageAt);
  }
}
