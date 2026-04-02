import '../models/ai_context_snapshot.dart';
import '../models/kline.dart';
import '../models/performance_summary.dart';
import '../services/performance_summary_calculator.dart';
import '../trading/strategy.dart';

class AiContextAnalyzer {
  const AiContextAnalyzer._();

  static AiContextSnapshot analyze(
    List<Kline> history, {
    StrategyAnalysisContext? context,
  }) {
    if (history.isEmpty) {
      return const AiContextSnapshot(
        marketRegime: 'Waiting',
        riskPosture: 'Balanced',
        tradeReviewState: 'Unproven',
        shortMomentumPercent: 0,
        mediumMomentumPercent: 0,
        rangeWidthPercent: 0,
        rangePositionPercent: 50,
        volatilityPercent: 0,
        volumeRatio: 1,
        rsi14: 50,
        suggestedSizeFraction: 0.0,
      );
    }

    final recent = history.length > 24
        ? history.sublist(history.length - 24)
        : history;
    final current = recent.last.close;
    final shortAnchor =
        recent[recent.length >= 4 ? recent.length - 4 : 0].close;
    final mediumAnchor =
        recent[recent.length >= 9 ? recent.length - 9 : 0].close;
    final shortMomentum = _percentChange(shortAnchor, current);
    final mediumMomentum = _percentChange(mediumAnchor, current);

    var highest = recent.first.high;
    var lowest = recent.first.low;
    for (final candle in recent) {
      if (candle.high > highest) {
        highest = candle.high;
      }
      if (candle.low < lowest) {
        lowest = candle.low;
      }
    }

    final rangeWidthPercent = current == 0
        ? 0.0
        : ((highest - lowest) / current) * 100;
    final rangeSpan = highest - lowest;
    final rangePositionPercent = rangeSpan <= 0
        ? 50.0
        : ((current - lowest) / rangeSpan * 100).clamp(0, 100).toDouble();
    final volatilityPercent = _averageRangePercent(recent);
    final volumeRatio = _volumeRatio(recent);
    final rsi14 = _calculateRsi(recent, period: 14);

    final symbolSummary = context == null
        ? const PerformanceSummary.empty()
        : PerformanceSummaryCalculator.calculate(context.symbolTrades);
    final accountSummary = context == null
        ? const PerformanceSummary.empty()
        : PerformanceSummaryCalculator.calculate(context.accountTrades);

    final tradeReviewState = _classifyTradeReview(
      symbolSummary,
      accountSummary,
    );
    final riskPosture = _classifyRiskPosture(
      context,
      tradeReviewState: tradeReviewState,
    );
    final marketRegime = _classifyMarketRegime(
      shortMomentumPercent: shortMomentum,
      mediumMomentumPercent: mediumMomentum,
      rangeWidthPercent: rangeWidthPercent,
      rangePositionPercent: rangePositionPercent,
      volatilityPercent: volatilityPercent,
      rsi14: rsi14,
    );
    final suggestedSizeFraction = _suggestSizeFraction(
      marketRegime: marketRegime,
      riskPosture: riskPosture,
      tradeReviewState: tradeReviewState,
      hasOpenSymbolPosition: context?.openPosition != null,
    );

    return AiContextSnapshot(
      marketRegime: marketRegime,
      riskPosture: riskPosture,
      tradeReviewState: tradeReviewState,
      shortMomentumPercent: shortMomentum,
      mediumMomentumPercent: mediumMomentum,
      rangeWidthPercent: rangeWidthPercent,
      rangePositionPercent: rangePositionPercent,
      volatilityPercent: volatilityPercent,
      volumeRatio: volumeRatio,
      rsi14: rsi14,
      suggestedSizeFraction: suggestedSizeFraction,
    );
  }

  static double _percentChange(double from, double to) {
    if (from == 0) {
      return 0;
    }
    return ((to - from) / from) * 100;
  }

  static double _averageRangePercent(List<Kline> history) {
    final sample = history.length > 14
        ? history.sublist(history.length - 14)
        : history;
    if (sample.isEmpty) {
      return 0;
    }

    final total = sample.fold<double>(0.0, (sum, candle) {
      if (candle.close == 0) {
        return sum;
      }
      return sum + (((candle.high - candle.low) / candle.close) * 100);
    });
    return total / sample.length;
  }

  static double _volumeRatio(List<Kline> history) {
    if (history.length < 2) {
      return 1.0;
    }

    final previous = history.length > 9
        ? history.sublist(history.length - 9, history.length - 1)
        : history.sublist(0, history.length - 1);
    final average =
        previous.fold<double>(0.0, (sum, candle) => sum + candle.volume) /
        previous.length;
    if (average == 0) {
      return 1.0;
    }
    return history.last.volume / average;
  }

  static double _calculateRsi(List<Kline> history, {required int period}) {
    if (history.length < 2) {
      return 50.0;
    }

    final usablePeriod = history.length - 1 < period
        ? history.length - 1
        : period;
    if (usablePeriod <= 0) {
      return 50.0;
    }

    var avgGain = 0.0;
    var avgLoss = 0.0;
    for (var i = 1; i <= usablePeriod; i++) {
      final change =
          history[history.length - i].close -
          history[history.length - i - 1].close;
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss -= change;
      }
    }

    avgGain /= usablePeriod;
    avgLoss /= usablePeriod;

    if (avgLoss == 0) {
      return avgGain == 0 ? 50.0 : 100.0;
    }

    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  static String _classifyTradeReview(
    PerformanceSummary symbolSummary,
    PerformanceSummary accountSummary,
  ) {
    final summary = symbolSummary.hasData ? symbolSummary : accountSummary;
    if (!summary.hasData) {
      return 'Unproven';
    }
    if (summary.totalPnL > 0 && summary.winRate >= 60) {
      return 'Hot';
    }
    if (summary.totalPnL < 0 ||
        summary.winRate <= 35 ||
        summary.maxDrawdown >= 15) {
      return 'Cold';
    }
    return 'Mixed';
  }

  static String _classifyRiskPosture(
    StrategyAnalysisContext? context, {
    required String tradeReviewState,
  }) {
    if (context == null) {
      return 'Balanced';
    }

    final wallet = context.walletBalance;
    final available = context.availableBalance;
    final availableRatio = wallet == null || wallet <= 0 || available == null
        ? null
        : available / wallet;

    if ((context.openPositionCount ?? 0) >= 3 ||
        (availableRatio != null && availableRatio < 0.25)) {
      return 'Defensive';
    }
    if (context.openPosition != null ||
        (availableRatio != null && availableRatio < 0.5)) {
      return 'Loaded';
    }
    if (tradeReviewState == 'Cold') {
      return 'Cautious';
    }
    if (tradeReviewState == 'Hot' &&
        (availableRatio == null || availableRatio > 0.65) &&
        (context.openPositionCount ?? 0) == 0) {
      return 'Aggressive';
    }
    return 'Balanced';
  }

  static String _classifyMarketRegime({
    required double shortMomentumPercent,
    required double mediumMomentumPercent,
    required double rangeWidthPercent,
    required double rangePositionPercent,
    required double volatilityPercent,
    required double rsi14,
  }) {
    if (mediumMomentumPercent >= 1.5 &&
        shortMomentumPercent >= 0.5 &&
        rangePositionPercent >= 60) {
      return rsi14 >= 70 ? 'Trend Up (Extended)' : 'Trend Up';
    }
    if (mediumMomentumPercent <= -1.5 &&
        shortMomentumPercent <= -0.5 &&
        rangePositionPercent <= 40) {
      return rsi14 <= 30 ? 'Trend Down (Extended)' : 'Trend Down';
    }
    if (rangeWidthPercent <= 1.6 && volatilityPercent <= 0.45) {
      return 'Squeeze';
    }
    if (mediumMomentumPercent.abs() <= 0.7 &&
        rangePositionPercent >= 35 &&
        rangePositionPercent <= 65) {
      return 'Range';
    }
    if (mediumMomentumPercent > 0.8 && shortMomentumPercent < 0) {
      return 'Pullback';
    }
    if (mediumMomentumPercent < -0.8 && shortMomentumPercent > 0) {
      return 'Relief Bounce';
    }
    if (volatilityPercent >= 2.5 || rangeWidthPercent >= 6) {
      return 'High Volatility';
    }
    return 'Mixed';
  }

  static double _suggestSizeFraction({
    required String marketRegime,
    required String riskPosture,
    required String tradeReviewState,
    required bool hasOpenSymbolPosition,
  }) {
    var size = switch (marketRegime) {
      'Trend Up' || 'Trend Down' => 0.80,
      'Trend Up (Extended)' || 'Trend Down (Extended)' => 0.60,
      'Range' => 0.55,
      'Pullback' || 'Relief Bounce' => 0.50,
      'Squeeze' => 0.35,
      'High Volatility' => 0.40,
      _ => 0.45,
    };

    switch (tradeReviewState) {
      case 'Hot':
        size += 0.10;
        break;
      case 'Cold':
        size -= 0.20;
        break;
      case 'Unproven':
        size -= 0.05;
        break;
      case 'Mixed':
        break;
    }

    switch (riskPosture) {
      case 'Aggressive':
        size += 0.10;
        break;
      case 'Balanced':
        break;
      case 'Loaded':
        size -= 0.15;
        break;
      case 'Cautious':
        size -= 0.15;
        break;
      case 'Defensive':
        size -= 0.30;
        break;
    }

    if (hasOpenSymbolPosition) {
      size = size > 0.35 ? 0.35 : size;
    }

    return size.clamp(0.15, 1.0).toDouble();
  }
}
