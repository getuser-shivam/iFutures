import '../models/order_book_snapshot.dart';
import '../models/order_book_trend_snapshot.dart';

class OrderBookTrendAnalyzer {
  const OrderBookTrendAnalyzer._();

  static OrderBookTrendSnapshot? analyze(
    List<OrderBookSnapshot> history, {
    int maxSamples = 6,
  }) {
    if (history.isEmpty) {
      return null;
    }

    final sample = history.length > maxSamples
        ? history.sublist(history.length - maxSamples)
        : history;
    final ordered = [...sample]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final first = ordered.first;
    final latest = ordered.last;

    final spreads = ordered
        .map((item) => item.spreadPercent)
        .whereType<double>()
        .toList(growable: false);
    final avgSpread = spreads.isEmpty ? null : _average(spreads);
    final spreadDrift =
        (latest.spreadPercent ?? 0.0) - (first.spreadPercent ?? 0.0);

    final avgImbalance = _average(
      ordered.map((item) => item.imbalancePercent).toList(growable: false),
    );
    final imbalanceDrift = latest.imbalancePercent - first.imbalancePercent;

    final worstSlippages = ordered
        .map(_worstSlippage)
        .whereType<double>()
        .toList(growable: false);
    final latestWorstSlippage = _worstSlippage(latest);
    final avgWorstSlippage = worstSlippages.isEmpty
        ? null
        : _average(worstSlippages);

    return OrderBookTrendSnapshot(
      sampleCount: ordered.length,
      latestSpreadPercent: latest.spreadPercent,
      averageSpreadPercent: avgSpread,
      spreadDriftPercent: spreadDrift,
      latestImbalancePercent: latest.imbalancePercent,
      averageImbalancePercent: avgImbalance,
      imbalanceDriftPercent: imbalanceDrift,
      latestWorstSlippagePercent: latestWorstSlippage,
      averageWorstSlippagePercent: avgWorstSlippage,
      trendLabel: _trendLabel(
        avgSpread: avgSpread,
        spreadDrift: spreadDrift,
        latestImbalance: latest.imbalancePercent,
        avgImbalance: avgImbalance,
        avgWorstSlippage: avgWorstSlippage,
      ),
    );
  }

  static double _average(List<double> values) =>
      values.reduce((sum, value) => sum + value) / values.length;

  static double? _worstSlippage(OrderBookSnapshot snapshot) {
    final buy = snapshot.estimatedBuySlippagePercent;
    final sell = snapshot.estimatedSellSlippagePercent;
    if (buy == null && sell == null) {
      return null;
    }
    return (buy ?? 0.0) > (sell ?? 0.0) ? (buy ?? 0.0) : (sell ?? 0.0);
  }

  static String _trendLabel({
    required double? avgSpread,
    required double spreadDrift,
    required double latestImbalance,
    required double avgImbalance,
    required double? avgWorstSlippage,
  }) {
    if ((avgSpread ?? 0.0) <= 0.03 &&
        spreadDrift <= 0.005 &&
        latestImbalance.abs() <= 8 &&
        (avgWorstSlippage ?? 0.0) <= 0.05) {
      return 'Stable balanced book';
    }

    if (spreadDrift <= -0.02 && latestImbalance >= 8) {
      return 'Tightening bid support';
    }
    if (spreadDrift <= -0.02 && latestImbalance <= -8) {
      return 'Tightening ask pressure';
    }
    if (spreadDrift >= 0.03 && latestImbalance >= 10) {
      return 'Widening with bid pressure';
    }
    if (spreadDrift >= 0.03 && latestImbalance <= -10) {
      return 'Widening with ask pressure';
    }
    if (avgImbalance >= 10) {
      return 'Persistent bid support';
    }
    if (avgImbalance <= -10) {
      return 'Persistent ask pressure';
    }
    if ((avgWorstSlippage ?? 0.0) >= 0.12 || spreadDrift >= 0.03) {
      return 'Liquidity worsening';
    }
    return 'Mixed intraminute book';
  }
}
