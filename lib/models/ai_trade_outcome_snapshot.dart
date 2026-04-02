class AiTradeOutcomeSnapshot {
  final String symbol;
  final String positionSideLabel;
  final double realizedPnl;
  final double quantity;
  final double exitPrice;
  final DateTime closedAt;
  final String reason;
  final String strategy;
  final String outcomeLabel;

  const AiTradeOutcomeSnapshot({
    required this.symbol,
    required this.positionSideLabel,
    required this.realizedPnl,
    required this.quantity,
    required this.exitPrice,
    required this.closedAt,
    required this.reason,
    required this.strategy,
    required this.outcomeLabel,
  });

  bool get isWin => realizedPnl > 0;
  bool get isLoss => realizedPnl < 0;

  String get summaryLine {
    final pnlText = realizedPnl >= 0
        ? '+${realizedPnl.toStringAsFixed(4)}'
        : realizedPnl.toStringAsFixed(4);
    return '$outcomeLabel on $positionSideLabel $symbol ($pnlText) via $reason.';
  }
}
