import '../models/ai_trade_outcome_snapshot.dart';
import '../models/portfolio_analytics_snapshot.dart';
import '../models/portfolio_symbol_breakdown.dart';
import '../models/position.dart';
import '../models/trade.dart';
import '../services/performance_summary_calculator.dart';
import '../services/trade_outcome_analyzer.dart';
import '../trading/strategy.dart';

class PortfolioAnalyticsCalculator {
  const PortfolioAnalyticsCalculator._();

  static PortfolioAnalyticsSnapshot calculate({
    required String selectedSymbol,
    required List<Trade> accountTrades,
    required Position? openPosition,
    required double? latestPrice,
    required double? walletBalance,
    required double? availableBalance,
    required int? openPositionCount,
    required StrategyTradePlan? latestPlan,
    required List<AiTradeOutcomeSnapshot> recentTradeOutcomes,
    DateTime? now,
  }) {
    final realizedSummary = PerformanceSummaryCalculator.calculate(
      accountTrades,
    );
    final todaySummary = PerformanceSummaryCalculator.calculateForDay(
      accountTrades,
      now ?? DateTime.now(),
    );

    final trackedSymbols = <String>{
      for (final trade in accountTrades) trade.symbol.toUpperCase(),
    };
    if (openPosition != null) {
      trackedSymbols.add(openPosition.symbol.toUpperCase());
    }
    final normalizedSelectedSymbol = selectedSymbol.toUpperCase();
    final breakdowns = _buildSymbolBreakdowns(
      accountTrades: accountTrades,
      selectedSymbol: normalizedSelectedSymbol,
      openPosition: openPosition,
    );
    final unrealizedPnl = _calculateUnrealizedPnl(openPosition, latestPrice);
    final unrealizedPercent = _calculateUnrealizedPercent(
      openPosition,
      latestPrice,
    );
    final liquidationDistancePercent = _calculateLiquidationDistancePercent(
      openPosition,
      latestPrice,
    );

    return PortfolioAnalyticsSnapshot(
      selectedSymbol: normalizedSelectedSymbol,
      walletBalance: walletBalance,
      availableBalance: availableBalance,
      openPositionCount: openPositionCount,
      trackedSymbolCount: trackedSymbols.length,
      currentSymbolExposure: openPosition == null
          ? null
          : openPosition.entryPrice * openPosition.quantity,
      currentPositionSideLabel: openPosition == null
          ? null
          : (openPosition.isLong ? 'LONG' : 'SHORT'),
      currentPositionEntryPrice: openPosition?.entryPrice,
      currentPositionLastPrice: latestPrice,
      currentPositionQuantity: openPosition?.quantity,
      currentPositionOpenedAt: openPosition?.entryTime,
      currentPositionLiquidationPrice: openPosition?.liquidationPrice,
      currentPositionLiquidationDistancePercent: liquidationDistancePercent,
      currentPositionUnrealizedPnl: unrealizedPnl,
      currentPositionUnrealizedPercent: unrealizedPercent,
      realizedSummary: realizedSummary,
      todaySummary: todaySummary,
      outcomeBias: TradeOutcomeAnalyzer.summarizeBias(recentTradeOutcomes),
      latestOutcomeLine: recentTradeOutcomes.isEmpty
          ? null
          : recentTradeOutcomes.first.summaryLine,
      latestPlanLabel: latestPlan?.summaryLabel,
      latestPlanMarketRegime: latestPlan?.marketRegime,
      latestPlanRiskPosture: latestPlan?.riskPosture,
      latestPlanAlignment: latestPlan?.timeframeAlignment,
      latestPlanExecutionHint: latestPlan?.executionHint,
      latestPlanMemoryLabel: latestPlan?.recentOutcomeLabel,
      symbolBreakdowns: breakdowns,
    );
  }

  static List<PortfolioSymbolBreakdown> _buildSymbolBreakdowns({
    required List<Trade> accountTrades,
    required String selectedSymbol,
    required Position? openPosition,
  }) {
    final grouped = <String, List<Trade>>{};
    for (final trade in accountTrades) {
      final symbol = trade.symbol.toUpperCase();
      grouped.putIfAbsent(symbol, () => <Trade>[]).add(trade);
    }

    final openSymbol = openPosition?.symbol.toUpperCase();
    if (openSymbol != null) {
      grouped.putIfAbsent(openSymbol, () => <Trade>[]);
    }

    final breakdowns =
        grouped.entries.map((entry) {
          final symbol = entry.key;
          final trades = entry.value;
          final exits = trades
              .where(
                (trade) => trade.kind == 'EXIT' && trade.realizedPnl != null,
              )
              .toList();
          final realizedPnl = exits.fold<double>(
            0,
            (sum, trade) => sum + (trade.realizedPnl ?? 0),
          );
          final totalFees = trades.fold<double>(
            0,
            (sum, trade) => sum + (trade.fee ?? 0),
          );
          DateTime? latestActivityAt;
          for (final trade in trades) {
            final timestamp = trade.timestamp;
            if (latestActivityAt == null ||
                timestamp.isAfter(latestActivityAt)) {
              latestActivityAt = timestamp;
            }
          }
          final isSelectedSymbol = symbol == selectedSymbol;
          final liveExposure = isSelectedSymbol && openPosition != null
              ? openPosition.entryPrice * openPosition.quantity
              : null;

          return PortfolioSymbolBreakdown(
            symbol: symbol,
            closedTrades: exits.length,
            winningTrades: exits
                .where(
                  (trade) =>
                      PerformanceSummaryCalculator.realizedPnlAfterFee(trade) >
                      0,
                )
                .length,
            realizedPnl: realizedPnl,
            totalFees: totalFees,
            latestActivityAt: latestActivityAt,
            liveExposure: liveExposure,
            isSelectedSymbol: isSelectedSymbol,
          );
        }).toList()..sort((left, right) {
          if (left.isSelectedSymbol != right.isSelectedSymbol) {
            return left.isSelectedSymbol ? -1 : 1;
          }

          final pnlCompare = right.netPnl.compareTo(left.netPnl);
          if (pnlCompare != 0) {
            return pnlCompare;
          }

          final leftActivity =
              left.latestActivityAt?.millisecondsSinceEpoch ?? 0;
          final rightActivity =
              right.latestActivityAt?.millisecondsSinceEpoch ?? 0;
          return rightActivity.compareTo(leftActivity);
        });

    return breakdowns;
  }

  static double? _calculateUnrealizedPnl(
    Position? openPosition,
    double? latestPrice,
  ) {
    if (openPosition == null || latestPrice == null) {
      return null;
    }

    return openPosition.isLong
        ? (latestPrice - openPosition.entryPrice) * openPosition.quantity
        : (openPosition.entryPrice - latestPrice) * openPosition.quantity;
  }

  static double? _calculateUnrealizedPercent(
    Position? openPosition,
    double? latestPrice,
  ) {
    if (openPosition == null ||
        latestPrice == null ||
        openPosition.entryPrice <= 0) {
      return null;
    }

    final move = openPosition.isLong
        ? (latestPrice - openPosition.entryPrice)
        : (openPosition.entryPrice - latestPrice);
    return (move / openPosition.entryPrice) * 100;
  }

  static double? _calculateLiquidationDistancePercent(
    Position? openPosition,
    double? latestPrice,
  ) {
    final liquidationPrice = openPosition?.liquidationPrice;
    if (liquidationPrice == null ||
        liquidationPrice <= 0 ||
        latestPrice == null ||
        latestPrice <= 0) {
      return null;
    }

    return ((latestPrice - liquidationPrice).abs() / latestPrice) * 100;
  }
}
