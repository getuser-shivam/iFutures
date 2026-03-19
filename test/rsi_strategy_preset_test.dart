import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/models/rsi_strategy_preset.dart';
import 'package:ifutures/trading/strategy.dart';

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
  test('finds the balanced RSI preset from its tuned values', () {
    final preset = findRsiStrategyPreset(
      period: 14,
      overbought: 70,
      oversold: 30,
    );

    expect(preset, isNotNull);
    expect(preset!.key, 'balanced');
    expect(preset.summary, 'RSI 14 / 70 / 30');
  });

  test('maps a preset to a working RSI strategy', () async {
    final strategy = rsiStrategyPresets
        .firstWhere((preset) => preset.key == 'balanced')
        .toStrategy();
    final history = List.generate(
      15,
      (index) => _kline(index, 100 - index.toDouble()),
    );

    final signal = await strategy.evaluate(history);

    expect(signal, TradingSignal.buy);
  });
}
