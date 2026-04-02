class RiskSettings {
  final double stopLossPercent;
  final double takeProfitPercent;
  final double tradeQuantity;
  final int leverage;
  final int cooldownMinutes;
  final int protectionPauseMinutes;
  final int maxConsecutiveLosses;
  final double maxDrawdownPercent;

  const RiskSettings({
    required this.stopLossPercent,
    required this.takeProfitPercent,
    required this.tradeQuantity,
    this.leverage = 1,
    this.cooldownMinutes = 0,
    this.protectionPauseMinutes = 30,
    this.maxConsecutiveLosses = 0,
    this.maxDrawdownPercent = 0,
  });

  bool get hasStopLoss => stopLossPercent > 0;
  bool get hasTakeProfit => takeProfitPercent > 0;
  bool get hasCooldown => cooldownMinutes > 0;
  bool get hasLossStreakProtection =>
      maxConsecutiveLosses > 0 && protectionPauseMinutes > 0;
  bool get hasDrawdownProtection =>
      maxDrawdownPercent > 0 && protectionPauseMinutes > 0;
}
