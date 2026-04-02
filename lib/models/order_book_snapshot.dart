class OrderBookSnapshot {
  final DateTime capturedAt;
  final double? bestBid;
  final double? bestAsk;
  final double? midPrice;
  final double? spread;
  final double? spreadPercent;
  final double bidDepthNotional;
  final double askDepthNotional;
  final double imbalancePercent;
  final int levelsAnalyzed;
  final double plannedQuantity;
  final double? estimatedBuyFillPrice;
  final double? estimatedSellFillPrice;
  final double? estimatedBuySlippagePercent;
  final double? estimatedSellSlippagePercent;
  final String executionHint;

  const OrderBookSnapshot({
    required this.capturedAt,
    required this.bestBid,
    required this.bestAsk,
    required this.midPrice,
    required this.spread,
    required this.spreadPercent,
    required this.bidDepthNotional,
    required this.askDepthNotional,
    required this.imbalancePercent,
    required this.levelsAnalyzed,
    required this.plannedQuantity,
    required this.estimatedBuyFillPrice,
    required this.estimatedSellFillPrice,
    required this.estimatedBuySlippagePercent,
    required this.estimatedSellSlippagePercent,
    required this.executionHint,
  });
}
