import '../models/kline.dart';
import '../models/ai_timeframe_snapshot.dart';
import '../models/manual_order.dart';
import '../models/order_book_snapshot.dart';
import '../models/position.dart';
import '../models/risk_settings.dart';
import '../models/trade.dart';

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
  final double? sizeFraction;
  final double? longBiasPrice;
  final double? shortBiasPrice;
  final String? marketRegime;
  final String? riskPosture;
  final String? tradeReviewState;
  final String? timeframeAlignment;
  final String? executionHint;
  final double? spreadPercent;
  final double? orderBookImbalancePercent;
  final double? estimatedBuySlippagePercent;
  final double? estimatedSellSlippagePercent;
  final List<AiTimeframeSnapshot> timeframeSnapshots;

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
    this.sizeFraction,
    this.longBiasPrice,
    this.shortBiasPrice,
    this.marketRegime,
    this.riskPosture,
    this.tradeReviewState,
    this.timeframeAlignment,
    this.executionHint,
    this.spreadPercent,
    this.orderBookImbalancePercent,
    this.estimatedBuySlippagePercent,
    this.estimatedSellSlippagePercent,
    this.timeframeSnapshots = const <AiTimeframeSnapshot>[],
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
    double? sizeFraction,
    double? longBiasPrice,
    double? shortBiasPrice,
    String? marketRegime,
    String? riskPosture,
    String? tradeReviewState,
    String? timeframeAlignment,
    String? executionHint,
    double? spreadPercent,
    double? orderBookImbalancePercent,
    double? estimatedBuySlippagePercent,
    double? estimatedSellSlippagePercent,
    List<AiTimeframeSnapshot> timeframeSnapshots =
        const <AiTimeframeSnapshot>[],
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
      sizeFraction: sizeFraction,
      longBiasPrice: longBiasPrice,
      shortBiasPrice: shortBiasPrice,
      marketRegime: marketRegime,
      riskPosture: riskPosture,
      tradeReviewState: tradeReviewState,
      timeframeAlignment: timeframeAlignment,
      executionHint: executionHint,
      spreadPercent: spreadPercent,
      orderBookImbalancePercent: orderBookImbalancePercent,
      estimatedBuySlippagePercent: estimatedBuySlippagePercent,
      estimatedSellSlippagePercent: estimatedSellSlippagePercent,
      timeframeSnapshots: timeframeSnapshots,
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

class StrategyAnalysisContext {
  final Position? openPosition;
  final List<Trade> symbolTrades;
  final List<Trade> accountTrades;
  final double? walletBalance;
  final double? availableBalance;
  final int? openPositionCount;
  final DateTime? accountSyncedAt;
  final String? accountStatusMessage;
  final OrderBookSnapshot? orderBookSnapshot;
  final DateTime? orderBookSyncedAt;

  const StrategyAnalysisContext({
    this.openPosition,
    this.symbolTrades = const <Trade>[],
    this.accountTrades = const <Trade>[],
    this.walletBalance,
    this.availableBalance,
    this.openPositionCount,
    this.accountSyncedAt,
    this.accountStatusMessage,
    this.orderBookSnapshot,
    this.orderBookSyncedAt,
  });
}

abstract class TradePlanningStrategy {
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
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
