enum MarketConnectionState {
  connecting,
  connected,
  stale,
  reconnecting,
  disconnected,
}

class ConnectionStatus {
  final MarketConnectionState state;
  final int? latencyMs;
  final DateTime? lastMessageAt;
  final int? retryAttempt;
  final int? retryDelayMs;
  final String? errorMessage;

  const ConnectionStatus({
    required this.state,
    this.latencyMs,
    this.lastMessageAt,
    this.retryAttempt,
    this.retryDelayMs,
    this.errorMessage,
  });

  factory ConnectionStatus.connecting() =>
      const ConnectionStatus(state: MarketConnectionState.connecting);

  factory ConnectionStatus.connected({
    int? latencyMs,
    DateTime? lastMessageAt,
  }) {
    return ConnectionStatus(
      state: MarketConnectionState.connected,
      latencyMs: latencyMs,
      lastMessageAt: lastMessageAt,
    );
  }

  factory ConnectionStatus.reconnecting({
    int? retryAttempt,
    int? retryDelayMs,
    DateTime? lastMessageAt,
    String? errorMessage,
  }) {
    return ConnectionStatus(
      state: MarketConnectionState.reconnecting,
      lastMessageAt: lastMessageAt,
      retryAttempt: retryAttempt,
      retryDelayMs: retryDelayMs,
      errorMessage: errorMessage,
    );
  }

  factory ConnectionStatus.disconnected({DateTime? lastMessageAt}) {
    return ConnectionStatus(
      state: MarketConnectionState.disconnected,
      lastMessageAt: lastMessageAt,
    );
  }

  ConnectionStatus copyWith({
    MarketConnectionState? state,
    int? latencyMs,
    DateTime? lastMessageAt,
    int? retryAttempt,
    int? retryDelayMs,
    String? errorMessage,
  }) {
    return ConnectionStatus(
      state: state ?? this.state,
      latencyMs: latencyMs ?? this.latencyMs,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      retryAttempt: retryAttempt ?? this.retryAttempt,
      retryDelayMs: retryDelayMs ?? this.retryDelayMs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
