import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/services/trade_outcome_analyzer.dart';

void main() {
  test('summarizes recent stop-loss pressure as cooling after stop losses', () {
    final outcomes = TradeOutcomeAnalyzer.analyze([
      Trade(
        symbol: 'TRIAUSDT',
        side: 'SELL',
        price: 0.028,
        quantity: 1,
        timestamp: DateTime(2026, 4, 2, 12, 00),
        strategy: 'AI Analyst',
        kind: 'EXIT',
        realizedPnl: -0.12,
        reason: 'stop_loss',
      ),
      Trade(
        symbol: 'TRIAUSDT',
        side: 'BUY',
        price: 0.027,
        quantity: 1,
        timestamp: DateTime(2026, 4, 2, 12, 10),
        strategy: 'AI Analyst',
        kind: 'EXIT',
        realizedPnl: -0.08,
        reason: 'stop_loss',
      ),
    ]);

    expect(outcomes, hasLength(2));
    expect(
      TradeOutcomeAnalyzer.summarizeBias(outcomes),
      'Cooling after stop losses',
    );
    expect(outcomes.first.outcomeLabel, 'Stopped out');
  });

  test('summarizes recent wins as pressing recent edge', () {
    final outcomes = TradeOutcomeAnalyzer.analyze([
      Trade(
        symbol: 'TRIAUSDT',
        side: 'SELL',
        price: 0.028,
        quantity: 1,
        timestamp: DateTime(2026, 4, 2, 12, 00),
        strategy: 'AI Analyst',
        kind: 'EXIT',
        realizedPnl: 0.12,
        reason: 'take_profit',
      ),
      Trade(
        symbol: 'TRIAUSDT',
        side: 'BUY',
        price: 0.027,
        quantity: 1,
        timestamp: DateTime(2026, 4, 2, 12, 10),
        strategy: 'AI Analyst',
        kind: 'EXIT',
        realizedPnl: 0.08,
        reason: 'manual_stop',
      ),
    ]);

    expect(
      TradeOutcomeAnalyzer.summarizeBias(outcomes),
      'Pressing recent edge',
    );
    expect(outcomes.first.summaryLine, contains('Profitable exit'));
  });

  test('treats a gross win below commission as a losing outcome', () {
    final outcomes = TradeOutcomeAnalyzer.analyze([
      Trade(
        symbol: 'ARIAUSDT',
        side: 'SELL',
        price: 0.10,
        quantity: 1,
        timestamp: DateTime(2026, 4, 2, 12, 20),
        fee: 0.05,
        strategy: 'AI Analyst',
        kind: 'EXIT',
        realizedPnl: 0.04,
        reason: 'take_profit',
      ),
    ]);

    expect(outcomes, hasLength(1));
    expect(outcomes.single.realizedPnl, closeTo(-0.01, 1e-12));
    expect(outcomes.single.isLoss, isTrue);
    expect(outcomes.single.outcomeLabel, 'Losing exit');
  });
}
