import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/models/manual_order.dart';
import 'package:ifutures/models/mock_test_result.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/services/mock_portfolio_test_service.dart';
import 'package:ifutures/trading/strategy.dart';

void main() {
  const service = MockPortfolioTestService();

  test('signal from a closed candle fills no earlier than next bar', () async {
    final candles = [
      _candle(0, open: 100, high: 101, low: 99, close: 100),
      _candle(1, open: 110, high: 111, low: 109, close: 110),
    ];

    final result = await service.run(
      klinesBySymbol: {'ARIAUSDT': candles},
      strategyFactory: (_) => _OneShotPlanStrategy(),
      riskSettings: _risk(),
      assumptions: _assumptions(),
    );

    final entry = result.symbolResults.single.trades.first;
    expect(entry.kind, 'ENTRY');
    expect(entry.price, 110);
    expect(entry.timestamp, candles[1].openTime);
    expect(result.netPnl, 0);
  });

  test('round-trip fees are included exactly once in net result', () async {
    final result = await service.run(
      klinesBySymbol: {
        'ARIAUSDT': [
          _candle(0, open: 100, high: 100, low: 100, close: 100),
          _candle(1, open: 100, high: 100, low: 100, close: 100),
        ],
      },
      strategyFactory: (_) => _OneShotPlanStrategy(),
      riskSettings: _risk(),
      assumptions: _assumptions(feePercent: 0.1),
    );

    final symbol = result.symbolResults.single;
    expect(symbol.totalFees, closeTo(0.2, 1e-9));
    expect(symbol.netPnl, closeTo(-0.2, 1e-9));
    expect(symbol.summary.totalPnL, closeTo(-0.2, 1e-9));
  });

  test('same candle TP and SL conflict resolves stop first', () async {
    final result = await service.run(
      klinesBySymbol: {
        'ARIAUSDT': [
          _candle(0, open: 100, high: 101, low: 99, close: 100),
          _candle(1, open: 100, high: 106, low: 94, close: 100),
        ],
      },
      strategyFactory: (_) =>
          _OneShotPlanStrategy(takeProfitPercent: 5, stopLossPercent: 5),
      riskSettings: _risk(takeProfit: 5, stopLoss: 5),
      assumptions: _assumptions(),
    );

    final exit = result.symbolResults.single.trades.last;
    expect(exit.reason, 'stop_first_same_bar');
    expect(exit.price, 95);
    expect(result.netPnl, closeTo(-5, 1e-9));
  });

  test('untouched one-bar limit signal is not invented as a fill', () async {
    final result = await service.run(
      klinesBySymbol: {
        'ARIAUSDT': [
          _candle(0, open: 100, high: 101, low: 99, close: 100),
          _candle(1, open: 101, high: 102, low: 100, close: 101),
          _candle(2, open: 102, high: 103, low: 101, close: 102),
        ],
      },
      strategyFactory: (_) => _OneShotPlanStrategy(
        orderType: ManualOrderType.limit,
        targetEntryPrice: 99,
      ),
      riskSettings: _risk(),
      assumptions: _assumptions(),
    );

    final symbol = result.symbolResults.single;
    expect(symbol.trades, isEmpty);
    expect(symbol.unfilledLimitSignals, 1);
  });

  test('limit fill candle conservatively applies a touched stop', () async {
    final result = await service.run(
      klinesBySymbol: {
        'ARIAUSDT': [
          _candle(0, open: 100, high: 101, low: 99, close: 100),
          _candle(1, open: 101, high: 106, low: 94, close: 101),
        ],
      },
      strategyFactory: (_) => _OneShotPlanStrategy(
        orderType: ManualOrderType.limit,
        targetEntryPrice: 99,
        takeProfitPercent: 5,
        stopLossPercent: 5,
      ),
      riskSettings: _risk(takeProfit: 5, stopLoss: 5),
      assumptions: _assumptions(),
    );

    final symbol = result.symbolResults.single;
    expect(symbol.trades.map((trade) => trade.kind), ['ENTRY', 'EXIT']);
    expect(symbol.trades.last.reason, 'limit_fill_bar_stop');
    expect(symbol.trades.last.price, closeTo(94.05, 1e-9));
    expect(symbol.netPnl, closeTo(-4.95, 1e-9));
  });

  test('historical positive funding charges long positions', () async {
    final candles = [
      _candle(0, open: 100, high: 100, low: 100, close: 100, hours: 0),
      _candle(1, open: 100, high: 100, low: 100, close: 100, hours: 1),
      _candle(2, open: 100, high: 100, low: 100, close: 100, hours: 9),
    ];
    final result = await service.run(
      klinesBySymbol: {'BTCUSDT': candles},
      strategyFactory: (_) => _OneShotPlanStrategy(),
      riskSettings: _risk(),
      assumptions: _assumptions(useHistoricalFunding: true),
      fundingBySymbol: {
        'BTCUSDT': [
          MockFundingRatePoint(timestamp: candles[2].openTime, rate: 0.01),
        ],
      },
    );

    expect(result.symbolResults.single.totalFunding, closeTo(1, 1e-9));
    expect(result.netPnl, closeTo(-1, 1e-9));
  });

  test('multi-symbol aggregation reconciles regardless of map order', () async {
    final rising = [
      _candle(0, open: 100, high: 100, low: 100, close: 100),
      _candle(1, open: 100, high: 101, low: 99, close: 100),
      _candle(2, open: 110, high: 110, low: 110, close: 110),
    ];
    final falling = [
      _candle(0, open: 100, high: 100, low: 100, close: 100),
      _candle(1, open: 100, high: 101, low: 99, close: 100),
      _candle(2, open: 90, high: 90, low: 90, close: 90),
    ];

    Future<MockPortfolioTestResult> run(Map<String, List<Kline>> data) {
      return service.run(
        klinesBySymbol: data,
        strategyFactory: (_) => _OneShotPlanStrategy(),
        riskSettings: _risk(),
        assumptions: _assumptions(),
      );
    }

    final forward = await run({'ARIAUSDT': rising, 'BTCUSDT': falling});
    final reversed = await run({'BTCUSDT': falling, 'ARIAUSDT': rising});

    expect(forward.netPnl, closeTo(0, 1e-9));
    expect(forward.endingBalance, closeTo(1000, 1e-9));
    expect(forward.summary.totalTrades, 2);
    expect(reversed.netPnl, closeTo(forward.netPnl, 1e-9));
    expect(reversed.equityCurve.length, forward.equityCurve.length);
  });

  test(
    'fixed funding mode is disclosed without claiming data was unavailable',
    () async {
      final result = await service.run(
        klinesBySymbol: {
          'ARIAUSDT': [
            _candle(0, open: 100, high: 100, low: 100, close: 100),
            _candle(1, open: 100, high: 100, low: 100, close: 100),
          ],
        },
        strategyFactory: (_) => _OneShotPlanStrategy(),
        riskSettings: _risk(),
        assumptions: _assumptions(),
      );

      expect(
        result.warnings,
        contains(contains('Historical funding was disabled')),
      );
      expect(
        result.warnings,
        isNot(contains(contains('funding was unavailable'))),
      );
    },
  );

  test('rejects a negative fixed funding stress assumption', () async {
    await expectLater(
      service.run(
        klinesBySymbol: {
          'ARIAUSDT': [
            _candle(0, open: 100, high: 100, low: 100, close: 100),
            _candle(1, open: 100, high: 100, low: 100, close: 100),
          ],
        },
        strategyFactory: (_) => _OneShotPlanStrategy(),
        riskSettings: _risk(),
        assumptions: const MockTestAssumptions(
          startingBalanceUsdt: 1000,
          fundingPercentPer8Hours: -0.01,
        ),
      ),
      throwsArgumentError,
    );
  });
}

class _OneShotPlanStrategy extends TradingStrategy
    implements TradePlanningStrategy {
  final ManualOrderType orderType;
  final double? targetEntryPrice;
  final double takeProfitPercent;
  final double stopLossPercent;

  _OneShotPlanStrategy({
    this.orderType = ManualOrderType.market,
    this.targetEntryPrice,
    this.takeProfitPercent = 0,
    this.stopLossPercent = 0,
  });

  @override
  String get name => 'One Shot';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async =>
      history.length == 1 ? TradingSignal.buy : TradingSignal.hold;

  @override
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) async {
    final signal = await evaluate(history);
    return StrategyTradePlan(
      strategyName: name,
      signal: signal,
      orderType: signal == TradingSignal.hold ? null : orderType,
      currentPrice: history.last.close,
      targetEntryPrice: signal == TradingSignal.hold
          ? null
          : (targetEntryPrice ?? history.last.close),
      leverage: 1,
      takeProfitPercent: takeProfitPercent,
      stopLossPercent: stopLossPercent,
      rationale: 'Test plan',
      generatedAt: context?.asOf ?? history.last.closeTime,
      quantity: 1,
    );
  }
}

MockTestAssumptions _assumptions({
  double feePercent = 0,
  bool useHistoricalFunding = false,
}) {
  return MockTestAssumptions(
    startingBalanceUsdt: 1000,
    feePercentPerSide: feePercent,
    slippageBpsPerMarketFill: 0,
    fundingPercentPer8Hours: 0,
    useHistoricalFunding: useHistoricalFunding,
  );
}

RiskSettings _risk({double takeProfit = 0, double stopLoss = 0}) {
  return RiskSettings(
    stopLossPercent: stopLoss,
    takeProfitPercent: takeProfit,
    tradeQuantity: 1,
    investmentUsdt: 100,
    leverage: 1,
  );
}

Kline _candle(
  int index, {
  required double open,
  required double high,
  required double low,
  required double close,
  int? hours,
}) {
  final openTime = DateTime.utc(
    2026,
    1,
    1,
  ).add(Duration(hours: hours ?? index));
  return Kline(
    openTime: openTime,
    open: open,
    high: high,
    low: low,
    close: close,
    volume: 10,
    closeTime: openTime.add(const Duration(minutes: 59)),
  );
}
