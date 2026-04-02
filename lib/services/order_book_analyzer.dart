import '../models/order_book_snapshot.dart';

class OrderBookAnalyzer {
  const OrderBookAnalyzer._();

  static OrderBookSnapshot analyze(
    Map<String, dynamic> payload, {
    required double plannedQuantity,
    required DateTime capturedAt,
    int maxLevels = 12,
  }) {
    final bids = _parseLevels(payload['bids'], maxLevels);
    final asks = _parseLevels(payload['asks'], maxLevels);

    final bestBid = bids.isEmpty ? null : bids.first.price;
    final bestAsk = asks.isEmpty ? null : asks.first.price;
    final midPrice = bestBid == null || bestAsk == null
        ? null
        : (bestBid + bestAsk) / 2;
    final spread = bestBid == null || bestAsk == null
        ? null
        : bestAsk - bestBid;
    final spreadPercent = midPrice == null || midPrice == 0 || spread == null
        ? null
        : (spread / midPrice) * 100;

    final bidDepthNotional = bids.fold<double>(
      0,
      (sum, level) => sum + (level.price * level.quantity),
    );
    final askDepthNotional = asks.fold<double>(
      0,
      (sum, level) => sum + (level.price * level.quantity),
    );
    final totalDepth = bidDepthNotional + askDepthNotional;
    final imbalancePercent = totalDepth == 0
        ? 0.0
        : ((bidDepthNotional - askDepthNotional) / totalDepth) * 100;

    final estimatedBuyFillPrice = _sweepAveragePrice(asks, plannedQuantity);
    final estimatedSellFillPrice = _sweepAveragePrice(bids, plannedQuantity);
    final estimatedBuySlippagePercent = _slippagePercent(
      bestAsk,
      estimatedBuyFillPrice,
    );
    final estimatedSellSlippagePercent = _slippagePercent(
      bestBid,
      estimatedSellFillPrice,
    );

    return OrderBookSnapshot(
      capturedAt: capturedAt,
      bestBid: bestBid,
      bestAsk: bestAsk,
      midPrice: midPrice,
      spread: spread,
      spreadPercent: spreadPercent,
      bidDepthNotional: bidDepthNotional,
      askDepthNotional: askDepthNotional,
      imbalancePercent: imbalancePercent,
      levelsAnalyzed: bids.length > asks.length ? bids.length : asks.length,
      plannedQuantity: plannedQuantity,
      estimatedBuyFillPrice: estimatedBuyFillPrice,
      estimatedSellFillPrice: estimatedSellFillPrice,
      estimatedBuySlippagePercent: estimatedBuySlippagePercent,
      estimatedSellSlippagePercent: estimatedSellSlippagePercent,
      executionHint: _executionHint(
        spreadPercent: spreadPercent,
        imbalancePercent: imbalancePercent,
        estimatedBuySlippagePercent: estimatedBuySlippagePercent,
        estimatedSellSlippagePercent: estimatedSellSlippagePercent,
      ),
    );
  }

  static List<_OrderBookLevel> _parseLevels(Object? raw, int maxLevels) {
    if (raw is! List) {
      return const <_OrderBookLevel>[];
    }

    final levels = <_OrderBookLevel>[];
    for (final item in raw.take(maxLevels)) {
      if (item is! List || item.length < 2) {
        continue;
      }
      final price = double.tryParse(item[0].toString());
      final quantity = double.tryParse(item[1].toString());
      if (price == null || quantity == null) {
        continue;
      }
      levels.add(_OrderBookLevel(price: price, quantity: quantity));
    }
    return levels;
  }

  static double? _sweepAveragePrice(
    List<_OrderBookLevel> levels,
    double plannedQuantity,
  ) {
    if (levels.isEmpty || plannedQuantity <= 0) {
      return null;
    }

    var remaining = plannedQuantity;
    var totalCost = 0.0;
    var filled = 0.0;
    for (final level in levels) {
      if (remaining <= 0) {
        break;
      }
      final fill = remaining < level.quantity ? remaining : level.quantity;
      totalCost += fill * level.price;
      filled += fill;
      remaining -= fill;
    }

    if (filled <= 0) {
      return null;
    }
    return totalCost / filled;
  }

  static double? _slippagePercent(double? bestPrice, double? averageFillPrice) {
    if (bestPrice == null || averageFillPrice == null || bestPrice == 0) {
      return null;
    }
    return ((averageFillPrice - bestPrice).abs() / bestPrice) * 100;
  }

  static String _executionHint({
    required double? spreadPercent,
    required double imbalancePercent,
    required double? estimatedBuySlippagePercent,
    required double? estimatedSellSlippagePercent,
  }) {
    final buySlip = estimatedBuySlippagePercent ?? 0.0;
    final sellSlip = estimatedSellSlippagePercent ?? 0.0;
    final worstSlip = buySlip > sellSlip ? buySlip : sellSlip;

    if ((spreadPercent ?? 0) <= 0.02 && worstSlip <= 0.03) {
      return 'Market friendly';
    }
    if ((spreadPercent ?? 0) <= 0.05 && worstSlip <= 0.08) {
      return 'Tight book';
    }
    if ((spreadPercent ?? 0) >= 0.12 || worstSlip >= 0.18) {
      return 'Scaled or passive entries preferred';
    }
    if (imbalancePercent >= 12) {
      return 'Bid pressure favors patient longs';
    }
    if (imbalancePercent <= -12) {
      return 'Ask pressure favors patient shorts';
    }
    return 'Limit entry preferred';
  }
}

class _OrderBookLevel {
  final double price;
  final double quantity;

  const _OrderBookLevel({required this.price, required this.quantity});
}
