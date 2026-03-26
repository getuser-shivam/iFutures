class RiskSettings {
  final double stopLossPercent;
  final double takeProfitPercent;
  final double tradeQuantity;
  final int leverage;

  const RiskSettings({
    required this.stopLossPercent,
    required this.takeProfitPercent,
    required this.tradeQuantity,
    this.leverage = 1,
  });

  bool get hasStopLoss => stopLossPercent > 0;
  bool get hasTakeProfit => takeProfitPercent > 0;
}
