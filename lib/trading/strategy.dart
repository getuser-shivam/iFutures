import '../models/kline.dart';
import '../models/manual_order.dart';
import '../models/risk_settings.dart';

enum TradingSignal { buy, sell, hold }

class StrategyTradePlan {
  final String strategyName;
  final TradingSignal signal;
  final ManualOrderType? orderType;
  final double currentPrice;
  final double? targetEntryPrice;
  final int leverage;
  final double takeProfitPercent;
  final double stopLossPercent;
  final String rationale;
  final DateTime generatedAt;
  final double? quantity;
  final double? confidence;
  final double? longBiasPrice;
  final double? shortBiasPrice;

  const StrategyTradePlan({
    required this.strategyName,
    required this.signal,
    required this.currentPrice,
    required this.leverage,
    required this.takeProfitPercent,
    required this.stopLossPercent,
    required this.rationale,
    required this.generatedAt,
    this.quantity,
    this.orderType,
    this.targetEntryPrice,
    this.confidence,
    this.longBiasPrice,
    this.shortBiasPrice,
  });

  factory StrategyTradePlan.hold({
    required String strategyName,
    required double currentPrice,
    required int leverage,
    required double takeProfitPercent,
    required double stopLossPercent,
    required String rationale,
    double? quantity,
    double? confidence,
    double? longBiasPrice,
    double? shortBiasPrice,
  }) {
    return StrategyTradePlan(
      strategyName: strategyName,
      signal: TradingSignal.hold,
      currentPrice: currentPrice,
      leverage: leverage,
      takeProfitPercent: takeProfitPercent,
      stopLossPercent: stopLossPercent,
      rationale: rationale,
      generatedAt: DateTime.now(),
      quantity: quantity,
      confidence: confidence,
      longBiasPrice: longBiasPrice,
      shortBiasPrice: shortBiasPrice,
    );
  }

  bool get isActionable => signal != TradingSignal.hold;

  String get actionLabel => switch (signal) {
    TradingSignal.buy => 'LONG',
    TradingSignal.sell => 'SHORT',
    TradingSignal.hold => 'HOLD',
  };

  String get orderTypeLabel => orderType?.label ?? 'Watch';

  String get summaryLabel => '$actionLabel | $orderTypeLabel';

  double get effectiveEntryPrice => targetEntryPrice ?? currentPrice;

  double? get plannedNotional =>
      quantity == null ? null : effectiveEntryPrice * quantity!;

  double? get estimatedMarginRequired =>
      plannedNotional == null || leverage <= 0
      ? null
      : plannedNotional! / leverage;

  double? get takeProfitPrice {
    if (!isActionable || takeProfitPercent <= 0) {
      return null;
    }

    return switch (signal) {
      TradingSignal.buy =>
        effectiveEntryPrice * (1 + (takeProfitPercent / 100)),
      TradingSignal.sell =>
        effectiveEntryPrice * (1 - (takeProfitPercent / 100)),
      TradingSignal.hold => null,
    };
  }

  double? get stopLossPrice {
    if (!isActionable || stopLossPercent <= 0) {
      return null;
    }

    return switch (signal) {
      TradingSignal.buy => effectiveEntryPrice * (1 - (stopLossPercent / 100)),
      TradingSignal.sell => effectiveEntryPrice * (1 + (stopLossPercent / 100)),
      TradingSignal.hold => null,
    };
  }

  double? get projectedProfitAtTarget =>
      plannedNotional == null || takeProfitPercent <= 0
      ? null
      : plannedNotional! * (takeProfitPercent / 100);

  double? get projectedLossAtStop =>
      plannedNotional == null || stopLossPercent <= 0
      ? null
      : plannedNotional! * (stopLossPercent / 100);
}

abstract class TradePlanningStrategy {
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
  });
}

abstract class TradingStrategy {
  String get name;
  Future<TradingSignal> evaluate(List<Kline> history);
}

ManualOrderType selectAutoOrderType(List<Kline> history, TradingSignal signal) {
  if (signal == TradingSignal.hold || history.length < 2) {
    return ManualOrderType.limit;
  }

  final recent = history.length > 12
      ? history.sublist(history.length - 12)
      : history;
  final currentPrice = recent.last.close;
  final previousPrice = recent[recent.length - 2].close;
  final movePercent = previousPrice == 0
      ? 0.0
      : ((currentPrice - previousPrice).abs() / previousPrice) * 100;

  var highest = recent.first.high;
  var lowest = recent.first.low;
  for (final candle in recent) {
    if (candle.high > highest) {
      highest = candle.high;
    }
    if (candle.low < lowest) {
      lowest = candle.low;
    }
  }

  final rangePercent = currentPrice == 0
      ? 0.0
      : ((highest - lowest) / currentPrice) * 100;

  if (rangePercent >= 4.5 || movePercent >= 1.6) {
    return ManualOrderType.scaled;
  }
  if (movePercent >= 0.9) {
    return ManualOrderType.market;
  }
  if (rangePercent <= 1.0) {
    return ManualOrderType.postOnly;
  }
  return ManualOrderType.limit;
}

double? suggestTargetEntryPrice(
  double currentPrice,
  TradingSignal signal,
  ManualOrderType? orderType,
) {
  if (orderType == null || orderType == ManualOrderType.market) {
    return currentPrice;
  }

  return switch (signal) {
    TradingSignal.buy => currentPrice * 0.998,
    TradingSignal.sell => currentPrice * 1.002,
    TradingSignal.hold => null,
  };
}
