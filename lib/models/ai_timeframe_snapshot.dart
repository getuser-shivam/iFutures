class AiTimeframeSnapshot {
  final String label;
  final String regime;
  final double shortMomentumPercent;
  final double mediumMomentumPercent;
  final double rangeWidthPercent;
  final double rangePositionPercent;
  final double volatilityPercent;
  final double rsi14;

  const AiTimeframeSnapshot({
    required this.label,
    required this.regime,
    required this.shortMomentumPercent,
    required this.mediumMomentumPercent,
    required this.rangeWidthPercent,
    required this.rangePositionPercent,
    required this.volatilityPercent,
    required this.rsi14,
  });

  String get summaryLine =>
      '$label $regime, short ${shortMomentumPercent.toStringAsFixed(2)}%, '
      'medium ${mediumMomentumPercent.toStringAsFixed(2)}%, '
      'range ${rangePositionPercent.toStringAsFixed(0)}%, '
      'vol ${volatilityPercent.toStringAsFixed(2)}%, RSI ${rsi14.toStringAsFixed(1)}';
}

class AiMultiTimeframeSnapshot {
  final List<AiTimeframeSnapshot> timeframes;
  final String alignment;

  const AiMultiTimeframeSnapshot({
    required this.timeframes,
    required this.alignment,
  });

  AiTimeframeSnapshot? snapshotFor(String label) {
    for (final snapshot in timeframes) {
      if (snapshot.label == label) {
        return snapshot;
      }
    }
    return null;
  }

  String get summaryLine {
    if (timeframes.isEmpty) {
      return 'Multi-timeframe context unavailable.';
    }
    return '${timeframes.map((item) => item.summaryLine).join(' | ')}. Alignment: $alignment.';
  }
}
