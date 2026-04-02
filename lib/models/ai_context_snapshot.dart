class AiContextSnapshot {
  final String marketRegime;
  final String riskPosture;
  final String tradeReviewState;
  final double shortMomentumPercent;
  final double mediumMomentumPercent;
  final double rangeWidthPercent;
  final double rangePositionPercent;
  final double volatilityPercent;
  final double volumeRatio;
  final double rsi14;
  final double suggestedSizeFraction;

  const AiContextSnapshot({
    required this.marketRegime,
    required this.riskPosture,
    required this.tradeReviewState,
    required this.shortMomentumPercent,
    required this.mediumMomentumPercent,
    required this.rangeWidthPercent,
    required this.rangePositionPercent,
    required this.volatilityPercent,
    required this.volumeRatio,
    required this.rsi14,
    required this.suggestedSizeFraction,
  });

  String get summaryLine =>
      '$marketRegime regime, $riskPosture posture, $tradeReviewState trade review. '
      'Short momentum ${shortMomentumPercent.toStringAsFixed(2)}%, '
      'medium momentum ${mediumMomentumPercent.toStringAsFixed(2)}%, '
      'range position ${rangePositionPercent.toStringAsFixed(0)}%, '
      'volatility ${volatilityPercent.toStringAsFixed(2)}%, '
      'volume ratio ${volumeRatio.toStringAsFixed(2)}, '
      'RSI ${rsi14.toStringAsFixed(1)}.';
}
