import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/trading/algo_strategy.dart';
import 'package:ifutures/trading/strategy.dart';

void main() {
  const riskSettings = RiskSettings(
    stopLossPercent: 0,
    takeProfitPercent: 0,
    tradeQuantity: 100,
    leverage: 10,
  );

  test('TRU range algo prefers a short near the upper band', () async {
    final strategy = RsiStrategy();
    final history = _buildTruRangeHistory(<double>[
      0.01185,
      0.01172,
      0.01155,
      0.01142,
      0.01130,
      0.01124,
      0.01120,
      0.01118,
    ]);

    final plan = await strategy.buildTradePlan(
      history,
      symbol: 'TRUUSDT',
      riskSettings: riskSettings,
    );

    expect(plan.signal, TradingSignal.sell);
    expect(plan.takeProfitPercent, greaterThan(0));
    expect(plan.stopLossPercent, greaterThan(0));
    expect(plan.rationale, contains('24h ceiling'));
    expect(plan.rationale, contains('one minute'));
    expect(plan.generatedAt, history.last.closeTime);
  });

  test('TRU range algo waits one minute after a profitable exit', () async {
    final strategy = RsiStrategy();
    final history = _buildTruRangeHistory(<double>[
      0.0107,
      0.0109,
      0.01105,
      0.01118,
      0.01112,
      0.01108,
    ]);
    final asOf = history.last.closeTime;

    final plan = await strategy.buildTradePlan(
      history,
      symbol: 'TRUUSDT',
      riskSettings: riskSettings,
      context: StrategyAnalysisContext(
        asOf: asOf,
        symbolTrades: <Trade>[
          Trade(
            symbol: 'TRUUSDT',
            side: 'BUY',
            price: 0.0104,
            quantity: 100,
            timestamp: asOf.subtract(const Duration(seconds: 25)),
            strategy: 'ALGO Engine',
            kind: 'EXIT',
            realizedPnl: 0.1,
          ),
        ],
      ),
    );

    expect(plan.signal, TradingSignal.hold);
    expect(plan.rationale, contains('cooling down'));
  });

  test(
    'TRU range algo can buy the lower band without perfect momentum reversal',
    () async {
      final strategy = RsiStrategy();
      final history = _buildTruRangeHistory(<double>[
        0.01055,
        0.01040,
        0.01024,
        0.01010,
        0.01002,
        0.00998,
        0.00995,
        0.00993,
      ]);

      final plan = await strategy.buildTradePlan(
        history,
        symbol: 'TRUUSDT',
        riskSettings: riskSettings,
      );

      expect(plan.signal, TradingSignal.buy);
      expect(plan.takeProfitPercent, greaterThan(0));
      expect(plan.stopLossPercent, greaterThan(0));
      expect(plan.rationale, contains('lower half of the range'));
    },
  );
}

List<Kline> _buildTruRangeHistory(List<double> tailPrices) {
  final candles = <Kline>[];
  final baseTime = DateTime(2026, 4, 6, 0, 0);

  for (var i = 0; i < 130 - tailPrices.length; i++) {
    final price = 0.0104 + ((i % 9) * 0.0001);
    candles.add(_kline(baseTime.add(Duration(minutes: i)), price));
  }

  for (var i = 0; i < tailPrices.length; i++) {
    candles.add(
      _kline(baseTime.add(Duration(minutes: candles.length)), tailPrices[i]),
    );
  }

  return candles;
}

Kline _kline(DateTime openTime, double close) {
  return Kline(
    openTime: openTime,
    open: close,
    high: close + 0.00008,
    low: close - 0.00008,
    close: close,
    volume: 1000,
    closeTime: openTime.add(const Duration(minutes: 1)),
  );
}
