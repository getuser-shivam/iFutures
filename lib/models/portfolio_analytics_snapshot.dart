import 'performance_summary.dart';
import 'portfolio_symbol_breakdown.dart';

class PortfolioAnalyticsSnapshot {
  final String selectedSymbol;
  final double? walletBalance;
  final double? availableBalance;
  final int? openPositionCount;
  final int trackedSymbolCount;
  final double? currentSymbolExposure;
  final String? currentPositionSideLabel;
  final double? currentPositionEntryPrice;
  final double? currentPositionLastPrice;
  final double? currentPositionQuantity;
  final DateTime? currentPositionOpenedAt;
  final double? currentPositionLiquidationPrice;
  final double? currentPositionLiquidationDistancePercent;
  final double? currentPositionUnrealizedPnl;
  final double? currentPositionUnrealizedPercent;
  final PerformanceSummary realizedSummary;
  final PerformanceSummary todaySummary;
  final String outcomeBias;
  final String? latestOutcomeLine;
  final String? latestPlanLabel;
  final String? latestPlanMarketRegime;
  final String? latestPlanRiskPosture;
  final String? latestPlanAlignment;
  final String? latestPlanExecutionHint;
  final String? latestPlanMemoryLabel;
  final List<PortfolioSymbolBreakdown> symbolBreakdowns;

  const PortfolioAnalyticsSnapshot({
    required this.selectedSymbol,
    required this.walletBalance,
    required this.availableBalance,
    required this.openPositionCount,
    required this.trackedSymbolCount,
    required this.currentSymbolExposure,
    required this.currentPositionSideLabel,
    required this.currentPositionEntryPrice,
    required this.currentPositionLastPrice,
    required this.currentPositionQuantity,
    required this.currentPositionOpenedAt,
    required this.currentPositionLiquidationPrice,
    required this.currentPositionLiquidationDistancePercent,
    required this.currentPositionUnrealizedPnl,
    required this.currentPositionUnrealizedPercent,
    required this.realizedSummary,
    required this.todaySummary,
    required this.outcomeBias,
    required this.latestOutcomeLine,
    required this.latestPlanLabel,
    required this.latestPlanMarketRegime,
    required this.latestPlanRiskPosture,
    required this.latestPlanAlignment,
    required this.latestPlanExecutionHint,
    required this.latestPlanMemoryLabel,
    required this.symbolBreakdowns,
  });

  double? get usedMargin {
    if (walletBalance == null || availableBalance == null) {
      return null;
    }
    final value = walletBalance! - availableBalance!;
    return value < 0 ? 0 : value;
  }

  double? get marginUsagePercent {
    final used = usedMargin;
    if (used == null || walletBalance == null || walletBalance! <= 0) {
      return null;
    }
    return (used / walletBalance!) * 100;
  }

  double? get exposureSharePercent {
    if (currentSymbolExposure == null ||
        walletBalance == null ||
        walletBalance! <= 0) {
      return null;
    }
    return (currentSymbolExposure! / walletBalance!) * 100;
  }

  bool get hasWalletSnapshot =>
      walletBalance != null ||
      availableBalance != null ||
      (openPositionCount != null && openPositionCount! > 0);

  bool get hasTradeData => realizedSummary.hasData || todaySummary.hasData;

  bool get hasSymbolBreakdowns => symbolBreakdowns.isNotEmpty;

  bool get hasOpenPosition =>
      currentPositionSideLabel != null &&
      currentPositionEntryPrice != null &&
      currentPositionQuantity != null;
}
