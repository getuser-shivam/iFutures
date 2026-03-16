class RiskSettings {
  final double stopLossPercent;
  final double takeProfitPercent;
  final double tradeQuantity;

  const RiskSettings({
    required this.stopLossPercent,
    required this.takeProfitPercent,
    required this.tradeQuantity,
  });

  bool get hasStopLoss => stopLossPercent > 0;
  bool get hasTakeProfit => takeProfitPercent > 0;
}
