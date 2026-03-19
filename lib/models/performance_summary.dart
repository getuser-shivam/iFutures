class PerformanceSummary {
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double totalPnL;
  final double bestTrade;
  final double worstTrade;
  final double avgTrade;
  final double maxDrawdown;
  final double profitFactor;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  const PerformanceSummary({
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.totalPnL,
    required this.bestTrade,
    required this.worstTrade,
    required this.avgTrade,
    required this.maxDrawdown,
    required this.profitFactor,
    this.windowStart,
    this.windowEnd,
  });

  const PerformanceSummary.empty({
    this.windowStart,
    this.windowEnd,
  })  : totalTrades = 0,
        winningTrades = 0,
        losingTrades = 0,
        totalPnL = 0,
        bestTrade = 0,
        worstTrade = 0,
        avgTrade = 0,
        maxDrawdown = 0,
        profitFactor = 0;

  double get winRate => totalTrades == 0 ? 0 : (winningTrades / totalTrades) * 100;

  bool get hasData => totalTrades > 0;
}
