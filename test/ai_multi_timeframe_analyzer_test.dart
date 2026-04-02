import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/services/ai_multi_timeframe_analyzer.dart';

void main() {
  test('detects bullish alignment when 1m, 5m, and 15m all trend higher', () {
    final history = _buildHistory(start: 1.0, step: 0.02, count: 60);

    final snapshot = AiMultiTimeframeAnalyzer.analyze(history);

    expect(snapshot.alignment, 'Bullish Alignment');
    expect(snapshot.snapshotFor('1m'), isNotNull);
    expect(snapshot.snapshotFor('5m'), isNotNull);
    expect(snapshot.snapshotFor('15m'), isNotNull);
  });

  test(
    'reports mixed alignment when short-term pullback fights the larger trend',
    () {
      final history = [
        ..._buildHistory(start: 1.0, step: 0.02, count: 45),
        ..._buildHistory(start: 1.9, step: -0.03, count: 15, minuteOffset: 45),
      ];

      final snapshot = AiMultiTimeframeAnalyzer.analyze(history);

      expect(snapshot.alignment, 'Mixed Alignment');
      expect(snapshot.snapshotFor('1m'), isNotNull);
      expect(snapshot.snapshotFor('5m'), isNotNull);
    },
  );
}

List<Kline> _buildHistory({
  required double start,
  required double step,
  required int count,
  int minuteOffset = 0,
}) {
  return List<Kline>.generate(count, (index) {
    final openTime = DateTime(2026, 4, 1, 0, minuteOffset + index);
    final close = start + (step * index);
    final open = close - (step / 2);
    final high = (open > close ? open : close) + 0.015;
    final low = (open < close ? open : close) - 0.015;
    return Kline(
      openTime: openTime,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 100 + (index * 2),
      closeTime: openTime.add(const Duration(minutes: 1)),
    );
  });
}
