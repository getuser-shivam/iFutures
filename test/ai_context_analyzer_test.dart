import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/models/position.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/services/ai_context_analyzer.dart';
import 'package:ifutures/trading/strategy.dart';

void main() {
  test('analyzer detects a healthy uptrend and allows larger AI sizing', () {
    final history = _buildTrendHistory(start: 1.0, step: 0.03, count: 24);
    final snapshot = AiContextAnalyzer.analyze(
      history,
      context: StrategyAnalysisContext(
        walletBalance: 120,
        availableBalance: 100,
        openPositionCount: 0,
        symbolTrades: [
          _exitTrade(pnl: 1.2, minutesAgo: 40, symbol: 'GALAUSDT'),
          _exitTrade(pnl: 0.8, minutesAgo: 20, symbol: 'GALAUSDT'),
        ],
        accountTrades: [
          _exitTrade(pnl: 1.2, minutesAgo: 40, symbol: 'GALAUSDT'),
          _exitTrade(pnl: 0.8, minutesAgo: 20, symbol: 'TRIAUSDT'),
        ],
      ),
    );

    expect(snapshot.marketRegime, contains('Trend Up'));
    expect(snapshot.tradeReviewState, 'Hot');
    expect(snapshot.riskPosture, 'Aggressive');
    expect(snapshot.suggestedSizeFraction, greaterThan(0.79));
  });

  test(
    'analyzer turns defensive after weak trade review and tight free margin',
    () {
      final history = _buildTrendHistory(start: 1.4, step: -0.035, count: 24);
      final snapshot = AiContextAnalyzer.analyze(
        history,
        context: StrategyAnalysisContext(
          walletBalance: 20,
          availableBalance: 3,
          openPositionCount: 4,
          openPosition: Position(
            symbol: 'GALAUSDT',
            side: PositionSide.short,
            entryPrice: 0.92,
            quantity: 10,
            entryTime: DateTime.now().subtract(const Duration(minutes: 15)),
          ),
          symbolTrades: [
            _exitTrade(pnl: -0.6, minutesAgo: 30, symbol: 'GALAUSDT'),
            _exitTrade(pnl: -0.3, minutesAgo: 10, symbol: 'GALAUSDT'),
          ],
          accountTrades: [
            _exitTrade(pnl: -0.6, minutesAgo: 30, symbol: 'GALAUSDT'),
            _exitTrade(pnl: -0.3, minutesAgo: 10, symbol: 'TRIAUSDT'),
          ],
        ),
      );

      expect(snapshot.tradeReviewState, 'Cold');
      expect(snapshot.riskPosture, 'Defensive');
      expect(snapshot.suggestedSizeFraction, lessThanOrEqualTo(0.2));
    },
  );
}

List<Kline> _buildTrendHistory({
  required double start,
  required double step,
  required int count,
}) {
  return List<Kline>.generate(count, (index) {
    final openTime = DateTime(2026, 4, 1, 0, index);
    final close = start + (step * index);
    final open = close - (step / 3);
    final high = close + 0.015.abs();
    final low = close - 0.015.abs();
    return Kline(
      openTime: openTime,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 100 + (index * 5),
      closeTime: openTime.add(const Duration(minutes: 1)),
    );
  });
}

Trade _exitTrade({
  required double pnl,
  required int minutesAgo,
  required String symbol,
}) {
  return Trade(
    symbol: symbol,
    side: pnl >= 0 ? 'SELL' : 'BUY',
    price: 1.0,
    quantity: 1,
    timestamp: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    status: 'filled',
    strategy: 'Test',
    kind: 'EXIT',
    realizedPnl: pnl,
  );
}
