import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/services/backtest_service.dart';
import 'package:ifutures/trading/strategy.dart';

class _ReversalStrategy extends TradingStrategy {
  @override
  String get name => 'Test Reversal';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    if (history.length == 1) return TradingSignal.buy;
    if (history.length == 3) return TradingSignal.sell;
    return TradingSignal.hold;
  }
}

class _StopLossStrategy extends TradingStrategy {
  @override
  String get name => 'Test Stop Loss';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    if (history.length == 1) return TradingSignal.buy;
    return TradingSignal.hold;
  }
}

Kline _kline(int minute, double close) {
  final openTime = DateTime(2026, 3, 19, 0, minute);
  return Kline(
    openTime: openTime,
    open: close,
    high: close,
    low: close,
    close: close,
    volume: 100,
    closeTime: openTime.add(const Duration(minutes: 1)),
  );
}

void main() {
  test('runs a backtest with reversal and end-of-run exit', () async {
    final service = BacktestService();
    final result = await service.run(
      symbol: 'GALAUSDT',
      strategy: _ReversalStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 0,
        takeProfitPercent: 0,
        tradeQuantity: 1,
      ),
      klines: [_kline(0, 100), _kline(1, 105), _kline(2, 110), _kline(3, 108)],
      startingBalance: 1000,
    );

    expect(result.candlesProcessed, 4);
    expect(result.summary.totalTrades, 2);
    expect(result.summary.totalPnL, 12);
    expect(result.endingBalance, 1012);
    expect(result.trades.where((trade) => trade.kind == 'ENTRY'), hasLength(2));
    expect(result.trades.where((trade) => trade.kind == 'EXIT'), hasLength(2));
    expect(
      result.trades.where((trade) => trade.kind == 'EXIT').first.realizedPnl,
      10,
    );
    expect(
      result.trades.where((trade) => trade.kind == 'EXIT').last.realizedPnl,
      2,
    );
  });

  test('closes open positions on stop loss', () async {
    final service = BacktestService();
    final result = await service.run(
      symbol: 'GALAUSDT',
      strategy: _StopLossStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 5,
        takeProfitPercent: 0,
        tradeQuantity: 1,
      ),
      klines: [_kline(0, 100), _kline(1, 94)],
      startingBalance: 1000,
    );

    expect(result.summary.totalTrades, 1);
    expect(result.summary.totalPnL, -6);
    expect(result.endingBalance, 994);
    expect(
      result.trades.where((trade) => trade.kind == 'EXIT').single.reason,
      'stop_loss',
    );
  });
}
