import 'performance_summary.dart';
import 'trade.dart';

class BacktestResult {
  final String symbol;
  final String strategyName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int candlesProcessed;
  final double startingBalance;
  final double endingBalance;
  final List<double> equityCurve;
  final List<Trade> trades;
  final PerformanceSummary summary;

  const BacktestResult({
    required this.symbol,
    required this.strategyName,
    required this.periodStart,
    required this.periodEnd,
    required this.candlesProcessed,
    required this.startingBalance,
    required this.endingBalance,
    required this.equityCurve,
    required this.trades,
    required this.summary,
  });

  bool get hasTrades => summary.hasData;

  double get netPnL => endingBalance - startingBalance;

  double get returnPercent =>
      startingBalance == 0 ? 0 : (netPnL / startingBalance) * 100;
}
