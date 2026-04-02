import '../models/performance_summary.dart';
import '../models/trade.dart';

class PerformanceSummaryCalculator {
  const PerformanceSummaryCalculator._();

  static PerformanceSummary calculate(
    Iterable<Trade> trades, {
    DateTime? windowStart,
    DateTime? windowEnd,
  }) {
    final realizedTrades =
        trades
            .where((trade) => trade.kind == 'EXIT' && trade.realizedPnl != null)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (realizedTrades.isEmpty) {
      return PerformanceSummary.empty(
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
    }

    final tradePnLs = realizedTrades
        .map((trade) => trade.realizedPnl!)
        .toList();
    final winningTrades = realizedTrades
        .where((trade) => trade.realizedPnl! > 0)
        .length;
    final losingTrades = realizedTrades
        .where((trade) => trade.realizedPnl! < 0)
        .length;

    final totalPnL = tradePnLs.fold(0.0, (sum, pnl) => sum + pnl);
    final bestTrade = tradePnLs.reduce((a, b) => a > b ? a : b);
    final worstTrade = tradePnLs.reduce((a, b) => a < b ? a : b);
    final avgTrade = totalPnL / realizedTrades.length;

    double cumulativePnL = 0.0;
    double peakPnL = 0.0;
    double maxDrawdown = 0.0;
    double grossProfit = 0.0;
    double grossLoss = 0.0;

    for (final pnl in tradePnLs) {
      cumulativePnL += pnl;

      if (pnl > 0) {
        grossProfit += pnl;
      } else if (pnl < 0) {
        grossLoss += pnl.abs();
      }

      if (cumulativePnL > peakPnL) {
        peakPnL = cumulativePnL;
      }

      if (peakPnL > 0) {
        final drawdown = ((peakPnL - cumulativePnL) / peakPnL) * 100;
        if (drawdown > maxDrawdown) {
          maxDrawdown = drawdown;
        }
      }
    }

    final profitFactor = grossLoss == 0
        ? double.infinity
        : grossProfit / grossLoss;

    return PerformanceSummary(
      totalTrades: realizedTrades.length,
      winningTrades: winningTrades,
      losingTrades: losingTrades,
      totalPnL: totalPnL,
      bestTrade: bestTrade,
      worstTrade: worstTrade,
      avgTrade: avgTrade,
      maxDrawdown: maxDrawdown,
      profitFactor: profitFactor,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }

  static PerformanceSummary calculateForDay(
    Iterable<Trade> trades,
    DateTime day,
  ) {
    final start = _startOfDay(day);
    final end = start.add(const Duration(days: 1));
    final filtered = filterTradesForDay(trades, day);
    return calculate(filtered, windowStart: start, windowEnd: end);
  }

  static List<Trade> filterTradesForDay(Iterable<Trade> trades, DateTime day) {
    final start = _startOfDay(day);
    final end = start.add(const Duration(days: 1));

    return trades.where((trade) {
      final timestamp = trade.timestamp.toLocal();
      return !timestamp.isBefore(start) && timestamp.isBefore(end);
    }).toList();
  }

  static DateTime _startOfDay(DateTime day) {
    final local = day.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
