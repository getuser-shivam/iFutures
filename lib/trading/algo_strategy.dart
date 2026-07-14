import '../models/kline.dart';
import '../models/manual_order.dart';
import '../models/risk_settings.dart';
import '../models/trade.dart';
import 'strategy.dart';

class RsiStrategy extends TradingStrategy implements TradePlanningStrategy {
  static const String _truSymbol = 'TRUUSDT';
  static const double _truRangeCeiling = 0.013;
  static const double _truShortTrigger = 0.011;
  static const double _truLongTrigger = 0.0102;
  static const double _truProfitStep = 0.001;
  static const double _truStopStep = 0.0006;
  static const Duration _truProfitCooldown = Duration(minutes: 1);
  static const int _truRangeWindowCandles = 1440;

  final int period;
  final double overbought;
  final double oversold;

  RsiStrategy({this.period = 14, this.overbought = 70.0, this.oversold = 30.0});

  @override
  String get name => 'ALGO Engine';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    if (history.length < period + 1) return TradingSignal.hold;

    final rsi = _calculateRsi(history);

    if (rsi < oversold) {
      return TradingSignal.buy;
    } else if (rsi > overbought) {
      return TradingSignal.sell;
    }

    return TradingSignal.hold;
  }

  @override
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) async {
    if (symbol?.trim().toUpperCase() == _truSymbol) {
      return _buildTruRangePlan(
        history,
        riskSettings: riskSettings,
        context: context,
      );
    }

    return _buildRsiTradePlan(
      history,
      riskSettings: riskSettings,
      context: context,
    );
  }

  Future<StrategyTradePlan> _buildRsiTradePlan(
    List<Kline> history, {
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) async {
    final currentPrice = history.isEmpty ? 0.0 : history.last.close;
    final leverage = riskSettings?.leverage ?? 1;
    final takeProfitPercent = riskSettings?.takeProfitPercent ?? 0.0;
    final stopLossPercent = riskSettings?.stopLossPercent ?? 0.0;
    final quantity =
        riskSettings?.resolveQuantity(currentPrice) ??
        riskSettings?.tradeQuantity;

    if (history.length < period + 1) {
      return StrategyTradePlan.hold(
        strategyName: name,
        currentPrice: currentPrice,
        leverage: leverage,
        takeProfitPercent: takeProfitPercent,
        stopLossPercent: stopLossPercent,
        quantity: quantity,
        rationale:
            'Waiting for at least ${period + 1} candles before RSI can evaluate.',
        confidence: 0.0,
      );
    }

    final rsi = _calculateRsi(history);
    final signal = await evaluate(history);
    if (signal == TradingSignal.hold) {
      final fallbackPlan = _buildNeutralRangeFallbackPlan(
        history,
        riskSettings: riskSettings,
        context: context,
      );
      if (fallbackPlan != null) {
        return fallbackPlan;
      }
    }
    final orderType = signal == TradingSignal.hold
        ? null
        : selectAutoOrderType(history, signal);
    final targetEntryPrice = suggestTargetEntryPrice(
      currentPrice,
      signal,
      orderType,
    );
    final confidence = ((rsi - 50).abs() / 50).clamp(0.0, 1.0).toDouble();

    final rationale = switch (signal) {
      TradingSignal.buy =>
        'RSI is ${rsi.toStringAsFixed(1)}, below the oversold threshold of ${oversold.toStringAsFixed(1)}. ${orderType?.label ?? 'Watch'} execution fits the current candle behavior.',
      TradingSignal.sell =>
        'RSI is ${rsi.toStringAsFixed(1)}, above the overbought threshold of ${overbought.toStringAsFixed(1)}. ${orderType?.label ?? 'Watch'} execution fits the current candle behavior.',
      TradingSignal.hold =>
        'RSI is ${rsi.toStringAsFixed(1)}, between the configured thresholds, so the algorithm prefers to wait.',
    };

    return StrategyTradePlan(
      strategyName: name,
      signal: signal,
      orderType: orderType,
      currentPrice: currentPrice,
      targetEntryPrice: targetEntryPrice,
      leverage: leverage,
      takeProfitPercent: takeProfitPercent,
      stopLossPercent: stopLossPercent,
      quantity: quantity,
      rationale: rationale,
      generatedAt: DateTime.now(),
      confidence: confidence,
    );
  }

  StrategyTradePlan _buildTruRangePlan(
    List<Kline> history, {
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) {
    final currentPrice = history.isEmpty ? 0.0 : history.last.close;
    final leverage = riskSettings?.leverage ?? 1;
    final quantity =
        riskSettings?.resolveQuantity(currentPrice) ??
        riskSettings?.tradeQuantity;

    if (history.length < 120) {
      return StrategyTradePlan.hold(
        strategyName: name,
        currentPrice: currentPrice,
        leverage: leverage,
        takeProfitPercent: 0.0,
        stopLossPercent: 0.0,
        quantity: quantity,
        rationale:
            'TRU range engine is waiting for at least 120 one-minute candles before it starts shaping the 24h short-range model.',
        confidence: 0.0,
      );
    }

    final window = history.length > _truRangeWindowCandles
        ? history.sublist(history.length - _truRangeWindowCandles)
        : history;
    var recentHigh = window.first.high;
    var recentLow = window.first.low;
    for (final candle in window) {
      if (candle.high > recentHigh) {
        recentHigh = candle.high;
      }
      if (candle.low < recentLow) {
        recentLow = candle.low;
      }
    }

    if (currentPrice >= _truRangeCeiling ||
        recentHigh > (_truRangeCeiling * 1.01)) {
      return StrategyTradePlan.hold(
        strategyName: name,
        currentPrice: currentPrice,
        leverage: leverage,
        takeProfitPercent: 0.0,
        stopLossPercent: 0.0,
        quantity: quantity,
        rationale:
            'TRU broke above the 24h range ceiling of ${_formatPrice(_truRangeCeiling)}, so the short-range model stands down until price settles back inside the band.',
        confidence: 0.2,
      );
    }

    final profitableExit = _latestProfitableExit(context);
    if (profitableExit != null) {
      final waitRemaining =
          _truProfitCooldown -
          DateTime.now().difference(profitableExit.timestamp);
      if (!waitRemaining.isNegative) {
        return StrategyTradePlan.hold(
          strategyName: name,
          currentPrice: currentPrice,
          leverage: leverage,
          takeProfitPercent: 0.0,
          stopLossPercent: 0.0,
          quantity: quantity,
          rationale:
              'TRU range engine banked a profit at ${_formatPrice(profitableExit.price)} and is cooling down for ${waitRemaining.inSeconds}s before choosing the next position.',
          confidence: 0.25,
        );
      }
    }

    final priorClose = history.length >= 2
        ? history[history.length - 2].close
        : currentPrice;
    final shortTermAnchor = history.length >= 6
        ? history[history.length - 6].close
        : history.first.close;
    final oneMinuteMomentum = currentPrice - priorClose;
    final fiveMinuteMomentum = currentPrice - shortTermAnchor;
    final cappedHigh = recentHigh > _truRangeCeiling
        ? _truRangeCeiling
        : recentHigh;
    final usableRange = cappedHigh - recentLow;
    final midRange = recentLow + (usableRange * 0.5);
    final shortLevel = _truShortTrigger > midRange
        ? _truShortTrigger
        : midRange;
    final longLevel = _truLongTrigger < midRange
        ? _truLongTrigger
        : recentLow + (usableRange * 0.25);
    final rangeProgress = usableRange <= 0
        ? 0.5
        : ((currentPrice - recentLow) / usableRange).clamp(0.0, 1.0);

    final orderBook = context?.orderBookSnapshot;
    final bearishBook = (orderBook?.imbalancePercent ?? 0) <= -6;
    final bullishBook = (orderBook?.imbalancePercent ?? 0) >= 6;
    var shortScore = 0;
    var longScore = 0;

    if (currentPrice >= shortLevel) {
      shortScore += 4;
    } else if (rangeProgress >= 0.58) {
      shortScore += 2;
    }

    if (currentPrice <= longLevel) {
      longScore += 4;
    } else if (rangeProgress <= 0.42) {
      longScore += 2;
    }

    if (oneMinuteMomentum <= 0) {
      shortScore += 1;
    } else {
      longScore += 1;
    }

    if (fiveMinuteMomentum <= 0) {
      shortScore += 1;
    } else {
      longScore += 1;
    }

    if (bearishBook) {
      shortScore += 1;
    }
    if (bullishBook) {
      longScore += 1;
    }

    final shortSetup =
        currentPrice < _truRangeCeiling &&
        rangeProgress >= 0.48 &&
        (currentPrice >= shortLevel || shortScore >= longScore + 1);
    final longSetup =
        rangeProgress <= 0.52 &&
        (currentPrice <= longLevel || longScore >= shortScore + 1);

    if (shortSetup) {
      final targetPrice = (currentPrice - _truProfitStep) > recentLow
          ? (currentPrice - _truProfitStep)
          : recentLow;
      final takeProfitPercent =
          ((currentPrice - targetPrice) / currentPrice) * 100;
      final stopAnchor = (currentPrice + _truStopStep) < _truRangeCeiling
          ? (currentPrice + _truStopStep)
          : _truRangeCeiling;
      final stopLossPercent =
          ((stopAnchor - currentPrice) / currentPrice) * 100;
      final orderType = _selectTruOrderType(
        history,
        TradingSignal.sell,
        context,
      );
      final confidence =
          (0.62 +
                  ((currentPrice - shortLevel) /
                          (_truRangeCeiling - shortLevel).clamp(
                            0.0001,
                            double.infinity,
                          )) *
                      0.18 +
                  (bearishBook ? 0.1 : 0.0))
              .clamp(0.0, 0.98);

      return StrategyTradePlan(
        strategyName: name,
        signal: TradingSignal.sell,
        orderType: orderType,
        currentPrice: currentPrice,
        targetEntryPrice: suggestTargetEntryPrice(
          currentPrice,
          TradingSignal.sell,
          orderType,
        ),
        leverage: leverage,
        takeProfitPercent: takeProfitPercent,
        stopLossPercent: stopLossPercent,
        quantity: quantity,
        rationale:
            'TRU remains inside the 24h ceiling at ${_formatPrice(_truRangeCeiling)}. Price is trading in the upper half of the range near ${_formatPrice(shortLevel)}, so the engine stops waiting for perfect confirmation and leans short for a ${_formatPrice(_truProfitStep)} step back toward ${_formatPrice(targetPrice)}. After any profitable exit it still pauses for one minute before re-entering.',
        generatedAt: DateTime.now(),
        confidence: confidence,
        executionHint: orderBook?.executionHint,
      );
    }

    if (longSetup) {
      final targetPrice = (currentPrice + _truProfitStep) < shortLevel
          ? (currentPrice + _truProfitStep)
          : shortLevel;
      final takeProfitPercent =
          ((targetPrice - currentPrice) / currentPrice) * 100;
      final stopAnchor = (currentPrice - _truStopStep) > recentLow
          ? (currentPrice - _truStopStep)
          : recentLow;
      final stopLossPercent =
          ((currentPrice - stopAnchor) / currentPrice) * 100;
      final orderType = _selectTruOrderType(
        history,
        TradingSignal.buy,
        context,
      );
      final confidence =
          (0.54 +
                  ((longLevel - currentPrice).abs() /
                          (longLevel.clamp(0.0001, double.infinity))) *
                      0.08 +
                  (bullishBook ? 0.1 : 0.0))
              .clamp(0.0, 0.9);

      return StrategyTradePlan(
        strategyName: name,
        signal: TradingSignal.buy,
        orderType: orderType,
        currentPrice: currentPrice,
        targetEntryPrice: suggestTargetEntryPrice(
          currentPrice,
          TradingSignal.buy,
          orderType,
        ),
        leverage: leverage,
        takeProfitPercent: takeProfitPercent,
        stopLossPercent: stopLossPercent,
        quantity: quantity,
        rationale:
            'TRU is trading in the lower half of the range near ${_formatPrice(longLevel)}. The engine now allows a rebound long toward ${_formatPrice(targetPrice)} without waiting for both momentum checks to flip positive first.',
        generatedAt: DateTime.now(),
        confidence: confidence,
        executionHint: orderBook?.executionHint,
      );
    }

    return StrategyTradePlan.hold(
      strategyName: name,
      currentPrice: currentPrice,
      leverage: leverage,
      takeProfitPercent: 0.0,
      stopLossPercent: 0.0,
      quantity: quantity,
      rationale:
          'TRU is sitting near the middle of the active range, between the short band at ${_formatPrice(shortLevel)} and the rebound band at ${_formatPrice(longLevel)}. The engine is waiting for price to lean back toward one edge before it commits.',
      confidence: 0.35,
      executionHint: orderBook?.executionHint,
    );
  }

  StrategyTradePlan? _buildNeutralRangeFallbackPlan(
    List<Kline> history, {
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) {
    if (history.length < 24) {
      return null;
    }

    final currentPrice = history.last.close;
    final leverage = riskSettings?.leverage ?? 1;
    final quantity =
        riskSettings?.resolveQuantity(currentPrice) ??
        riskSettings?.tradeQuantity;
    final lookback = history.length > 48
        ? history.sublist(history.length - 48)
        : history;

    var recentHigh = lookback.first.high;
    var recentLow = lookback.first.low;
    for (final candle in lookback) {
      if (candle.high > recentHigh) {
        recentHigh = candle.high;
      }
      if (candle.low < recentLow) {
        recentLow = candle.low;
      }
    }

    final usableRange = recentHigh - recentLow;
    if (usableRange <= 0) {
      return null;
    }

    final rangeProgress = ((currentPrice - recentLow) / usableRange).clamp(
      0.0,
      1.0,
    );
    final priorClose = history[history.length - 2].close;
    final shortAnchor = history[history.length - 6].close;
    final oneMinuteMomentum = currentPrice - priorClose;
    final fiveMinuteMomentum = currentPrice - shortAnchor;
    final orderBook = context?.orderBookSnapshot;
    final imbalance = orderBook?.imbalancePercent ?? 0.0;

    final upperShort =
        rangeProgress >= 0.68 &&
        (oneMinuteMomentum <= 0 || fiveMinuteMomentum <= 0 || imbalance <= -5);
    final lowerLong =
        rangeProgress <= 0.32 &&
        (oneMinuteMomentum >= 0 || fiveMinuteMomentum >= 0 || imbalance >= 5);

    if (!upperShort && !lowerLong) {
      return null;
    }

    final signal = upperShort ? TradingSignal.sell : TradingSignal.buy;
    final orderType = selectAutoOrderType(history, signal);
    final targetEntryPrice = suggestTargetEntryPrice(
      currentPrice,
      signal,
      orderType,
    );
    final confidence = upperShort
        ? (0.42 + ((rangeProgress - 0.68) * 0.6)).clamp(0.0, 0.74)
        : (0.42 + ((0.32 - rangeProgress) * 0.6)).clamp(0.0, 0.74);

    return StrategyTradePlan(
      strategyName: name,
      signal: signal,
      orderType: orderType,
      currentPrice: currentPrice,
      targetEntryPrice: targetEntryPrice,
      leverage: leverage,
      takeProfitPercent: riskSettings?.takeProfitPercent ?? 0.0,
      stopLossPercent: riskSettings?.stopLossPercent ?? 0.0,
      quantity: quantity,
      rationale: upperShort
          ? 'RSI is neutral, but price is pressing the upper edge of the recent range and momentum/order-book pressure is no longer supportive. The ALGO engine takes the short instead of waiting for a full RSI extreme.'
          : 'RSI is neutral, but price is leaning on the lower edge of the recent range and momentum/order-book pressure is stabilizing. The ALGO engine takes the long instead of waiting for a full RSI extreme.',
      generatedAt: DateTime.now(),
      confidence: confidence.toDouble(),
      executionHint: context?.orderBookSnapshot?.executionHint,
    );
  }

  double _calculateRsi(List<Kline> history) {
    // Simple RSI calculation logic
    double avgGain = 0.0;
    double avgLoss = 0.0;

    for (int i = 1; i <= period; i++) {
      final change =
          history[history.length - i].close -
          history[history.length - i - 1].close;
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss -= change;
      }
    }

    avgGain /= period;
    avgLoss /= period;

    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  ManualOrderType _selectTruOrderType(
    List<Kline> history,
    TradingSignal signal,
    StrategyAnalysisContext? context,
  ) {
    final orderBook = context?.orderBookSnapshot;
    final spread = orderBook?.spreadPercent ?? 0.0;
    final executionHint = orderBook?.executionHint.toLowerCase() ?? '';

    if (executionHint.contains('scaled') || spread >= 0.12) {
      return ManualOrderType.scaled;
    }
    if (signal == TradingSignal.sell &&
        (executionHint.contains('patient shorts') ||
            (orderBook?.imbalancePercent ?? 0) <= -10)) {
      return ManualOrderType.limit;
    }
    if (signal == TradingSignal.buy &&
        (executionHint.contains('patient longs') ||
            (orderBook?.imbalancePercent ?? 0) >= 10)) {
      return ManualOrderType.limit;
    }
    if (spread <= 0.02) {
      return ManualOrderType.market;
    }
    return selectAutoOrderType(history, signal);
  }

  Trade? _latestProfitableExit(StrategyAnalysisContext? context) {
    if (context == null) {
      return null;
    }

    final source = context.symbolTrades.isNotEmpty
        ? context.symbolTrades
        : context.accountTrades;
    for (final trade in source.reversed) {
      if (trade.kind == 'EXIT' && (trade.realizedPnl ?? 0) > 0) {
        return trade;
      }
    }
    return null;
  }

  String _formatPrice(double price) {
    if (price >= 100) {
      return price.toStringAsFixed(2);
    }
    if (price >= 1) {
      return price.toStringAsFixed(4);
    }
    return price.toStringAsFixed(6);
  }
}
