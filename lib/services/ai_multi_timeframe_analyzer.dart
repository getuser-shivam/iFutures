import '../models/ai_timeframe_snapshot.dart';
import '../models/kline.dart';
import 'ai_context_analyzer.dart';

class AiMultiTimeframeAnalyzer {
  const AiMultiTimeframeAnalyzer._();

  static AiMultiTimeframeSnapshot analyze(List<Kline> history) {
    if (history.isEmpty) {
      return const AiMultiTimeframeSnapshot(
        timeframes: <AiTimeframeSnapshot>[],
        alignment: 'Unavailable',
      );
    }

    final snapshots = <AiTimeframeSnapshot>[_analyzeFrame('1m', history)];

    final fiveMinute = _aggregate(history, 5);
    if (fiveMinute.length >= 4) {
      snapshots.add(_analyzeFrame('5m', fiveMinute));
    }

    final fifteenMinute = _aggregate(history, 15);
    if (fifteenMinute.length >= 4) {
      snapshots.add(_analyzeFrame('15m', fifteenMinute));
    }

    return AiMultiTimeframeSnapshot(
      timeframes: snapshots,
      alignment: _alignmentFor(snapshots),
    );
  }

  static AiTimeframeSnapshot _analyzeFrame(String label, List<Kline> history) {
    final snapshot = AiContextAnalyzer.analyze(history);
    return AiTimeframeSnapshot(
      label: label,
      regime: snapshot.marketRegime,
      shortMomentumPercent: snapshot.shortMomentumPercent,
      mediumMomentumPercent: snapshot.mediumMomentumPercent,
      rangeWidthPercent: snapshot.rangeWidthPercent,
      rangePositionPercent: snapshot.rangePositionPercent,
      volatilityPercent: snapshot.volatilityPercent,
      rsi14: snapshot.rsi14,
    );
  }

  static List<Kline> _aggregate(List<Kline> history, int minutes) {
    if (history.isEmpty) {
      return const <Kline>[];
    }

    final bucketMs = Duration(minutes: minutes).inMilliseconds;
    final aggregated = <Kline>[];

    DateTime? openTime;
    DateTime? closeTime;
    double? open;
    double? high;
    double? low;
    double? close;
    var volume = 0.0;
    int? activeBucket;

    void flush() {
      if (openTime == null ||
          closeTime == null ||
          open == null ||
          high == null ||
          low == null ||
          close == null) {
        return;
      }
      aggregated.add(
        Kline(
          openTime: openTime!,
          open: open!,
          high: high!,
          low: low!,
          close: close!,
          volume: volume,
          closeTime: closeTime!,
        ),
      );
    }

    for (final candle in history) {
      final bucket = candle.openTime.millisecondsSinceEpoch ~/ bucketMs;
      if (activeBucket == null || bucket != activeBucket) {
        flush();
        activeBucket = bucket;
        openTime = candle.openTime;
        closeTime = candle.closeTime;
        open = candle.open;
        high = candle.high;
        low = candle.low;
        close = candle.close;
        volume = candle.volume;
        continue;
      }

      closeTime = candle.closeTime;
      if (candle.high > (high ?? candle.high)) {
        high = candle.high;
      }
      if (candle.low < (low ?? candle.low)) {
        low = candle.low;
      }
      close = candle.close;
      volume += candle.volume;
    }

    flush();
    return aggregated;
  }

  static String _alignmentFor(List<AiTimeframeSnapshot> snapshots) {
    if (snapshots.isEmpty) {
      return 'Unavailable';
    }

    var bullish = 0;
    var bearish = 0;
    var compression = 0;

    for (final snapshot in snapshots) {
      final regime = snapshot.regime;
      if (_isBullishRegime(regime)) {
        bullish += 1;
      } else if (_isBearishRegime(regime)) {
        bearish += 1;
      } else if (regime == 'Squeeze' || regime == 'Range') {
        compression += 1;
      }
    }

    if (bullish >= 2 && bearish == 0) {
      return 'Bullish Alignment';
    }
    if (bearish >= 2 && bullish == 0) {
      return 'Bearish Alignment';
    }
    if (compression >= 2 && bullish == 0 && bearish == 0) {
      return 'Compression Alignment';
    }
    return 'Mixed Alignment';
  }

  static bool _isBullishRegime(String regime) {
    return regime.startsWith('Trend Up') || regime == 'Pullback';
  }

  static bool _isBearishRegime(String regime) {
    return regime.startsWith('Trend Down') || regime == 'Relief Bounce';
  }
}
