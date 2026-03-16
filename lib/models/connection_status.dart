enum MarketConnectionState {
  connecting,
  connected,
  stale,
  disconnected,
}

class ConnectionStatus {
  final MarketConnectionState state;
  final int? latencyMs;
  final DateTime? lastMessageAt;

  const ConnectionStatus({
    required this.state,
    this.latencyMs,
    this.lastMessageAt,
  });

  factory ConnectionStatus.connecting() =>
      const ConnectionStatus(state: MarketConnectionState.connecting);

  factory ConnectionStatus.disconnected({DateTime? lastMessageAt}) {
    return ConnectionStatus(
      state: MarketConnectionState.disconnected,
      lastMessageAt: lastMessageAt,
    );
  }
}
