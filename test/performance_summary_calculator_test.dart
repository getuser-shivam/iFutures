import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/services/performance_summary_calculator.dart';

Trade _exitTrade(double pnl, DateTime timestamp) {
  return Trade(
    symbol: 'GALAUSDT',
    side: 'BUY',
    price: 1.0,
    quantity: 1.0,
    timestamp: timestamp,
    status: 'filled',
    strategy: 'ALGO',
    kind: 'EXIT',
    realizedPnl: pnl,
  );
}

Trade _entryTrade(DateTime timestamp) {
  return Trade(
    symbol: 'GALAUSDT',
    side: 'BUY',
    price: 1.0,
    quantity: 1.0,
    timestamp: timestamp,
    status: 'filled',
    strategy: 'ALGO',
    kind: 'ENTRY',
  );
}

void main() {
  test('calculates realized performance summary from exit trades', () {
    final trades = [
      _exitTrade(6, DateTime(2026, 3, 19, 12)),
      _exitTrade(10, DateTime(2026, 3, 19, 10)),
      _exitTrade(-4, DateTime(2026, 3, 19, 11)),
    ];

    final summary = PerformanceSummaryCalculator.calculate(trades);

    expect(summary.totalTrades, 3);
    expect(summary.winningTrades, 2);
    expect(summary.losingTrades, 1);
    expect(summary.winRate, closeTo(66.666, 0.01));
    expect(summary.totalPnL, 12);
    expect(summary.bestTrade, 10);
    expect(summary.worstTrade, -4);
    expect(summary.avgTrade, 4);
    expect(summary.maxDrawdown, closeTo(40.0, 0.01));
    expect(summary.profitFactor, closeTo(4.0, 0.01));
    expect(summary.hasData, isTrue);
  });

  test('calculateForDay only includes trades from the local day window', () {
    final trades = [
      _exitTrade(1, DateTime(2026, 3, 18, 23, 59)),
      _exitTrade(2, DateTime(2026, 3, 19, 0, 0)),
      _exitTrade(3, DateTime(2026, 3, 19, 15, 0)),
      _exitTrade(4, DateTime(2026, 3, 20, 0, 0)),
    ];

    final summary = PerformanceSummaryCalculator.calculateForDay(trades, DateTime(2026, 3, 19));

    expect(summary.totalTrades, 2);
    expect(summary.totalPnL, 5);
    expect(summary.bestTrade, 3);
    expect(summary.worstTrade, 2);
  });

  test('returns an empty summary when there are no realized exits', () {
    final summary = PerformanceSummaryCalculator.calculate([
      _entryTrade(DateTime(2026, 3, 19, 10)),
    ]);

    expect(summary.hasData, isFalse);
    expect(summary.totalTrades, 0);
    expect(summary.totalPnL, 0);
    expect(summary.profitFactor, 0);
  });
}
