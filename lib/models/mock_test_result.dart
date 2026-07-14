import 'performance_summary.dart';
import 'trade.dart';

enum MockTestVerdict { insufficientSample, netPositive, netNegative }

class MockTestAssumptions {
  final double startingBalanceUsdt;
  final double feePercentPerSide;
  final double slippageBpsPerMarketFill;
  final double fundingPercentPer8Hours;
  final int limitOrderLifetimeBars;
  final bool useHistoricalFunding;

  const MockTestAssumptions({
    this.startingBalanceUsdt = 1000,
    this.feePercentPerSide = 0.05,
    this.slippageBpsPerMarketFill = 2,
    this.fundingPercentPer8Hours = 0.01,
    this.limitOrderLifetimeBars = 1,
    this.useHistoricalFunding = true,
  });

  double get feeRatePerSide => feePercentPerSide / 100;
  double get slippageRatePerMarketFill => slippageBpsPerMarketFill / 10000;
  double get fundingRatePer8Hours => fundingPercentPer8Hours / 100;
}

class MockFundingRatePoint {
  final DateTime timestamp;
  final double rate;

  const MockFundingRatePoint({required this.timestamp, required this.rate});
}

class MockEquityPoint {
  final DateTime timestamp;
  final double equity;

  const MockEquityPoint({required this.timestamp, required this.equity});
}

class MockSymbolTestResult {
  final String symbol;
  final String strategyName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int candlesProcessed;
  final double startingBalance;
  final double endingBalance;
  final double grossPnl;
  final double totalFees;
  final double totalFunding;
  final double estimatedSlippageCost;
  final int unfilledLimitSignals;
  final bool usedHistoricalFunding;
  final List<MockEquityPoint> equityCurve;
  final List<Trade> trades;
  final PerformanceSummary summary;

  const MockSymbolTestResult({
    required this.symbol,
    required this.strategyName,
    required this.periodStart,
    required this.periodEnd,
    required this.candlesProcessed,
    required this.startingBalance,
    required this.endingBalance,
    required this.grossPnl,
    required this.totalFees,
    required this.totalFunding,
    required this.estimatedSlippageCost,
    required this.unfilledLimitSignals,
    required this.usedHistoricalFunding,
    required this.equityCurve,
    required this.trades,
    required this.summary,
  });

  double get netPnl => endingBalance - startingBalance;

  double get returnPercent =>
      startingBalance <= 0 ? 0 : (netPnl / startingBalance) * 100;

  int get closedTrades => summary.totalTrades;

  double get maxDrawdownPercent => _maxDrawdownPercent(equityCurve);
}

class MockPortfolioTestResult {
  final MockTestAssumptions assumptions;
  final List<MockSymbolTestResult> symbolResults;
  final List<MockEquityPoint> equityCurve;
  final PerformanceSummary summary;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int requiredClosedTrades;
  final List<String> warnings;

  const MockPortfolioTestResult({
    required this.assumptions,
    required this.symbolResults,
    required this.equityCurve,
    required this.summary,
    required this.periodStart,
    required this.periodEnd,
    required this.requiredClosedTrades,
    this.warnings = const [],
  });

  double get startingBalance => assumptions.startingBalanceUsdt;

  double get endingBalance =>
      symbolResults.fold(0.0, (sum, result) => sum + result.endingBalance);

  double get netPnl => endingBalance - startingBalance;

  double get returnPercent =>
      startingBalance <= 0 ? 0 : (netPnl / startingBalance) * 100;

  double get totalFees =>
      symbolResults.fold(0.0, (sum, result) => sum + result.totalFees);

  double get totalFunding =>
      symbolResults.fold(0.0, (sum, result) => sum + result.totalFunding);

  double get estimatedSlippageCost => symbolResults.fold(
    0.0,
    (sum, result) => sum + result.estimatedSlippageCost,
  );

  int get unfilledLimitSignals =>
      symbolResults.fold(0, (sum, result) => sum + result.unfilledLimitSignals);

  int get profitableSymbols =>
      symbolResults.where((result) => result.netPnl > 0).length;

  double get maxDrawdownPercent => _maxDrawdownPercent(equityCurve);

  bool get hasEnoughTrades => summary.totalTrades >= requiredClosedTrades;

  MockTestVerdict get verdict {
    if (!hasEnoughTrades) return MockTestVerdict.insufficientSample;
    return netPnl > 0 && summary.profitFactor > 1
        ? MockTestVerdict.netPositive
        : MockTestVerdict.netNegative;
  }
}

double _maxDrawdownPercent(List<MockEquityPoint> curve) {
  if (curve.isEmpty) return 0;
  var peak = curve.first.equity;
  var maximum = 0.0;
  for (final point in curve) {
    if (point.equity > peak) peak = point.equity;
    if (peak <= 0) continue;
    final drawdown = ((peak - point.equity) / peak) * 100;
    if (drawdown > maximum) maximum = drawdown;
  }
  return maximum;
}
