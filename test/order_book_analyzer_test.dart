import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/services/order_book_analyzer.dart';

void main() {
  test('computes spread, imbalance, and sweep slippage from Binance depth', () {
    final snapshot = OrderBookAnalyzer.analyze(
      {
        'bids': [
          ['100.00', '2.0'],
          ['99.90', '3.0'],
          ['99.80', '5.0'],
        ],
        'asks': [
          ['100.10', '1.0'],
          ['100.20', '2.0'],
          ['100.30', '5.0'],
        ],
      },
      plannedQuantity: 2.5,
      capturedAt: DateTime(2026, 4, 1, 12, 0),
    );

    expect(snapshot.bestBid, 100.0);
    expect(snapshot.bestAsk, 100.1);
    expect(snapshot.spreadPercent, closeTo(0.09995, 0.0002));
    expect(snapshot.estimatedBuyFillPrice, closeTo(100.16, 0.0001));
    expect(snapshot.estimatedSellFillPrice, closeTo(99.98, 0.0001));
    expect(snapshot.estimatedBuySlippagePercent, greaterThan(0.05));
    expect(snapshot.executionHint, isNotEmpty);
  });

  test('prefers market-friendly hint when the book is tight', () {
    final snapshot = OrderBookAnalyzer.analyze(
      {
        'bids': [
          ['10.000', '50'],
          ['9.999', '50'],
        ],
        'asks': [
          ['10.001', '50'],
          ['10.002', '50'],
        ],
      },
      plannedQuantity: 1,
      capturedAt: DateTime(2026, 4, 1, 12, 1),
    );

    expect(snapshot.spreadPercent, lessThan(0.02));
    expect(snapshot.executionHint, anyOf('Market friendly', 'Tight book'));
  });
}
