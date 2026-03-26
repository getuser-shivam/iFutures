import '../models/kline.dart';
import '../models/manual_order.dart';
import '../models/risk_settings.dart';
import 'strategy.dart';

class RsiStrategy extends TradingStrategy implements TradePlanningStrategy {
  final int period;
  final double overbought;
  final double oversold;

  RsiStrategy({this.period = 14, this.overbought = 70.0, this.oversold = 30.0});

  @override
  String get name => "RSI Algorithm";

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
  }) async {
    final currentPrice = history.isEmpty ? 0.0 : history.last.close;
    final leverage = riskSettings?.leverage ?? 1;
    final takeProfitPercent = riskSettings?.takeProfitPercent ?? 0.0;
    final stopLossPercent = riskSettings?.stopLossPercent ?? 0.0;
    final quantity = riskSettings?.tradeQuantity;

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
}
