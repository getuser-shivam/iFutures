class OrderBookTrendSnapshot {
  final int sampleCount;
  final double? latestSpreadPercent;
  final double? averageSpreadPercent;
  final double spreadDriftPercent;
  final double latestImbalancePercent;
  final double averageImbalancePercent;
  final double imbalanceDriftPercent;
  final double? latestWorstSlippagePercent;
  final double? averageWorstSlippagePercent;
  final String trendLabel;

  const OrderBookTrendSnapshot({
    required this.sampleCount,
    required this.latestSpreadPercent,
    required this.averageSpreadPercent,
    required this.spreadDriftPercent,
    required this.latestImbalancePercent,
    required this.averageImbalancePercent,
    required this.imbalanceDriftPercent,
    required this.latestWorstSlippagePercent,
    required this.averageWorstSlippagePercent,
    required this.trendLabel,
  });

  String get summaryLine =>
      '$trendLabel. Avg spread ${averageSpreadPercent?.toStringAsFixed(4) ?? '--'}%, '
      'spread drift ${spreadDriftPercent.toStringAsFixed(4)}%, '
      'avg imbalance ${averageImbalancePercent.toStringAsFixed(1)}%, '
      'imbalance drift ${imbalanceDriftPercent.toStringAsFixed(1)}%.';
}
