import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/market_analysis.dart';

void main() {
  test('formats market price and asset labels cleanly', () {
    final asset = MarketAssetSnapshot(
      symbol: 'BTCUSDT',
      displayName: 'BTC',
      lastPrice: 70606.1234,
      changePercent: 1.246,
      highPrice: 71200,
      lowPrice: 69910,
      volume: 123456.789,
      updatedAt: DateTime(2026, 3, 20),
    );

    expect(formatMarketPrice(70606.1234), '70,606.12');
    expect(
      truncateText(
        'Bitcoin is trending higher after a strong week',
        maxLength: 15,
      ),
      'Bitcoin is tren...',
    );
    expect(MarketBias.bullish.label, 'Bullish');
    expect(asset.changeLabel, '+1.25%');
    expect(asset.rangeLabel, '69,910.00 - 71,200.00');
  });
}
