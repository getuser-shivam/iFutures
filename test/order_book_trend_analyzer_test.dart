import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/order_book_snapshot.dart';
import 'package:ifutures/services/order_book_trend_analyzer.dart';

void main() {
  test(
    'detects tightening bid support from improving spread and bid imbalance',
    () {
      final trend = OrderBookTrendAnalyzer.analyze([
        OrderBookSnapshot(
          capturedAt: DateTime(2026, 4, 2, 12, 0),
          bestBid: 1.0,
          bestAsk: 1.002,
          midPrice: 1.001,
          spread: 0.002,
          spreadPercent: 0.20,
          bidDepthNotional: 1500,
          askDepthNotional: 900,
          imbalancePercent: 12,
          levelsAnalyzed: 10,
          plannedQuantity: 1,
          estimatedBuyFillPrice: 1.0022,
          estimatedSellFillPrice: 0.9999,
          estimatedBuySlippagePercent: 0.08,
          estimatedSellSlippagePercent: 0.05,
          executionHint: 'Limit entry preferred',
        ),
        OrderBookSnapshot(
          capturedAt: DateTime(2026, 4, 2, 12, 1),
          bestBid: 1.0,
          bestAsk: 1.001,
          midPrice: 1.0005,
          spread: 0.001,
          spreadPercent: 0.10,
          bidDepthNotional: 1800,
          askDepthNotional: 800,
          imbalancePercent: 18,
          levelsAnalyzed: 10,
          plannedQuantity: 1,
          estimatedBuyFillPrice: 1.0011,
          estimatedSellFillPrice: 0.9999,
          estimatedBuySlippagePercent: 0.04,
          estimatedSellSlippagePercent: 0.02,
          executionHint: 'Tight book',
        ),
        OrderBookSnapshot(
          capturedAt: DateTime(2026, 4, 2, 12, 2),
          bestBid: 1.0,
          bestAsk: 1.0006,
          midPrice: 1.0003,
          spread: 0.0006,
          spreadPercent: 0.05,
          bidDepthNotional: 2000,
          askDepthNotional: 700,
          imbalancePercent: 22,
          levelsAnalyzed: 10,
          plannedQuantity: 1,
          estimatedBuyFillPrice: 1.0007,
          estimatedSellFillPrice: 0.9999,
          estimatedBuySlippagePercent: 0.02,
          estimatedSellSlippagePercent: 0.01,
          executionHint: 'Market friendly',
        ),
      ]);

      expect(trend, isNotNull);
      expect(trend!.trendLabel, 'Tightening bid support');
      expect(trend.sampleCount, 3);
      expect(trend.spreadDriftPercent, lessThan(0));
    },
  );

  test('detects liquidity worsening when spread and slippage expand', () {
    final trend = OrderBookTrendAnalyzer.analyze([
      OrderBookSnapshot(
        capturedAt: DateTime(2026, 4, 2, 12, 0),
        bestBid: 1.0,
        bestAsk: 1.0004,
        midPrice: 1.0002,
        spread: 0.0004,
        spreadPercent: 0.04,
        bidDepthNotional: 1000,
        askDepthNotional: 1000,
        imbalancePercent: 0,
        levelsAnalyzed: 10,
        plannedQuantity: 1,
        estimatedBuyFillPrice: 1.0005,
        estimatedSellFillPrice: 0.9999,
        estimatedBuySlippagePercent: 0.03,
        estimatedSellSlippagePercent: 0.02,
        executionHint: 'Tight book',
      ),
      OrderBookSnapshot(
        capturedAt: DateTime(2026, 4, 2, 12, 1),
        bestBid: 1.0,
        bestAsk: 1.002,
        midPrice: 1.001,
        spread: 0.002,
        spreadPercent: 0.20,
        bidDepthNotional: 700,
        askDepthNotional: 900,
        imbalancePercent: -12,
        levelsAnalyzed: 10,
        plannedQuantity: 1,
        estimatedBuyFillPrice: 1.003,
        estimatedSellFillPrice: 0.9992,
        estimatedBuySlippagePercent: 0.20,
        estimatedSellSlippagePercent: 0.08,
        executionHint: 'Scaled or passive entries preferred',
      ),
    ]);

    expect(trend, isNotNull);
    expect(trend!.trendLabel, 'Widening with ask pressure');
    expect(trend.averageWorstSlippagePercent, greaterThan(0.1));
  });
}
