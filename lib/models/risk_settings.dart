class RiskSettings {
  final double stopLossPercent;
  final double takeProfitPercent;
  final double tradeQuantity;
  final double? investmentUsdt;
  final double? targetProfitUsdt;
  final double? maxLossUsdt;
  final int leverage;
  final int cooldownMinutes;
  final int protectionPauseMinutes;
  final int maxConsecutiveLosses;
  final double maxDrawdownPercent;

  const RiskSettings({
    required this.stopLossPercent,
    required this.takeProfitPercent,
    required this.tradeQuantity,
    this.investmentUsdt,
    this.targetProfitUsdt,
    this.maxLossUsdt,
    this.leverage = 1,
    this.cooldownMinutes = 0,
    this.protectionPauseMinutes = 30,
    this.maxConsecutiveLosses = 0,
    this.maxDrawdownPercent = 0,
  });

  bool get hasAbsoluteStopLoss => maxLossUsdt != null && maxLossUsdt! > 0;
  bool get hasAbsoluteTakeProfit =>
      targetProfitUsdt != null && targetProfitUsdt! > 0;
  bool get hasStopLoss => hasAbsoluteStopLoss || stopLossPercent > 0;
  bool get hasTakeProfit => hasAbsoluteTakeProfit || takeProfitPercent > 0;
  bool get hasCooldown => cooldownMinutes > 0;
  bool get hasLossStreakProtection =>
      maxConsecutiveLosses > 0 && protectionPauseMinutes > 0;
  bool get hasDrawdownProtection =>
      maxDrawdownPercent > 0 && protectionPauseMinutes > 0;

  double? resolveQuantity(double? currentPrice) {
    if (investmentUsdt != null &&
        investmentUsdt! > 0 &&
        currentPrice != null &&
        currentPrice > 0 &&
        leverage > 0) {
      return (investmentUsdt! * leverage) / currentPrice;
    }
    return tradeQuantity > 0 ? tradeQuantity : null;
  }

  double? resolveNotional(double? currentPrice) {
    final quantity = resolveQuantity(currentPrice);
    if (quantity == null || currentPrice == null || currentPrice <= 0) {
      return null;
    }
    return quantity * currentPrice;
  }

  double? resolveEstimatedMargin(double? currentPrice) {
    final notional = resolveNotional(currentPrice);
    if (notional == null || leverage <= 0) {
      return null;
    }
    return notional / leverage;
  }

  double resolveTakeProfitPercent(
    double entryPrice, {
    required double quantity,
    double? fallbackPercent,
  }) {
    final notional = entryPrice * quantity;
    if (hasAbsoluteTakeProfit && notional > 0) {
      return (targetProfitUsdt! / notional) * 100;
    }
    return fallbackPercent != null && fallbackPercent > 0
        ? fallbackPercent
        : takeProfitPercent;
  }

  double resolveStopLossPercent(
    double entryPrice, {
    required double quantity,
    double? fallbackPercent,
  }) {
    final notional = entryPrice * quantity;
    if (hasAbsoluteStopLoss && notional > 0) {
      return (maxLossUsdt! / notional) * 100;
    }
    return fallbackPercent != null && fallbackPercent > 0
        ? fallbackPercent
        : stopLossPercent;
  }

  double? resolveEstimatedTakeProfitUsdt(double? entryPrice, double? quantity) {
    if (hasAbsoluteTakeProfit) {
      return targetProfitUsdt;
    }
    if (entryPrice == null || quantity == null || takeProfitPercent <= 0) {
      return null;
    }
    return entryPrice * quantity * (takeProfitPercent / 100);
  }

  double? resolveEstimatedMaxLossUsdt(double? entryPrice, double? quantity) {
    if (hasAbsoluteStopLoss) {
      return maxLossUsdt;
    }
    if (entryPrice == null || quantity == null || stopLossPercent <= 0) {
      return null;
    }
    return entryPrice * quantity * (stopLossPercent / 100);
  }
}
