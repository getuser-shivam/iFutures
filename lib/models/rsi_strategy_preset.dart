import '../trading/algo_strategy.dart';

class RsiStrategyPreset {
  final String key;
  final String label;
  final String description;
  final int period;
  final double overbought;
  final double oversold;

  const RsiStrategyPreset({
    required this.key,
    required this.label,
    required this.description,
    required this.period,
    required this.overbought,
    required this.oversold,
  });

  String get summary =>
      'RSI $period / ${overbought.toStringAsFixed(0)} / ${oversold.toStringAsFixed(0)}';

  RsiStrategy toStrategy() {
    return RsiStrategy(
      period: period,
      overbought: overbought,
      oversold: oversold,
    );
  }

  bool matches({
    required int period,
    required double overbought,
    required double oversold,
  }) {
    return this.period == period &&
        (this.overbought - overbought).abs() < 0.0001 &&
        (this.oversold - oversold).abs() < 0.0001;
  }
}

const List<RsiStrategyPreset> rsiStrategyPresets = [
  RsiStrategyPreset(
    key: 'balanced',
    label: 'Balanced',
    description: 'Default swing settings with a 14-period lookback.',
    period: 14,
    overbought: 70,
    oversold: 30,
  ),
  RsiStrategyPreset(
    key: 'conservative',
    label: 'Conservative',
    description: 'Waits for stronger confirmation before entering.',
    period: 21,
    overbought: 75,
    oversold: 25,
  ),
  RsiStrategyPreset(
    key: 'aggressive',
    label: 'Aggressive',
    description: 'Faster turns with a shorter lookback window.',
    period: 9,
    overbought: 65,
    oversold: 35,
  ),
  RsiStrategyPreset(
    key: 'trend',
    label: 'Trend',
    description: 'Favors trend continuation and earlier entries.',
    period: 12,
    overbought: 80,
    oversold: 40,
  ),
];

RsiStrategyPreset? findRsiStrategyPreset({
  required int period,
  required double overbought,
  required double oversold,
}) {
  for (final preset in rsiStrategyPresets) {
    if (preset.matches(
      period: period,
      overbought: overbought,
      oversold: oversold,
    )) {
      return preset;
    }
  }
  return null;
}
