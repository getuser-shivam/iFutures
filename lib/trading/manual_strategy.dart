import '../models/kline.dart';
import '../models/risk_settings.dart';
import 'strategy.dart';

class ManualStrategy extends TradingStrategy implements TradePlanningStrategy {
  @override
  String get name => 'Manual';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    return TradingSignal.hold;
  }

  @override
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
  }) async {
    return StrategyTradePlan.hold(
      strategyName: name,
      currentPrice: history.isEmpty ? 0.0 : history.last.close,
      leverage: riskSettings?.leverage ?? 1,
      takeProfitPercent: riskSettings?.takeProfitPercent ?? 0.0,
      stopLossPercent: riskSettings?.stopLossPercent ?? 0.0,
      rationale:
          'Manual mode is active. The strategy console will watch the market, but entry type and side stay under your control.',
      confidence: 1.0,
    );
  }
}
