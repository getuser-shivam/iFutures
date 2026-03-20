import 'package:intl/intl.dart';

enum MarketBias { bullish, neutral, bearish }

extension MarketBiasX on MarketBias {
  String get label => switch (this) {
    MarketBias.bullish => 'Bullish',
    MarketBias.neutral => 'Mixed',
    MarketBias.bearish => 'Bearish',
  };
}

class MarketAssetSnapshot {
  final String symbol;
  final String displayName;
  final double lastPrice;
  final double changePercent;
  final double highPrice;
  final double lowPrice;
  final double volume;
  final DateTime updatedAt;

  const MarketAssetSnapshot({
    required this.symbol,
    required this.displayName,
    required this.lastPrice,
    required this.changePercent,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.updatedAt,
  });

  bool get isPositive => changePercent >= 0;

  String get priceLabel => formatMarketPrice(lastPrice);

  String get changeLabel =>
      '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%';

  String get rangeLabel =>
      '${formatMarketPrice(lowPrice)} - ${formatMarketPrice(highPrice)}';
}

class MarketNewsItem {
  final String source;
  final String feedLabel;
  final String title;
  final String summary;
  final String link;

  const MarketNewsItem({
    required this.source,
    required this.feedLabel,
    required this.title,
    required this.summary,
    required this.link,
  });
}

class MarketAnalysisSnapshot {
  final DateTime updatedAt;
  final List<MarketAssetSnapshot> assets;
  final List<MarketNewsItem> news;
  final MarketBias bias;
  final String summary;
  final String shortWatch;

  const MarketAnalysisSnapshot({
    required this.updatedAt,
    required this.assets,
    required this.news,
    required this.bias,
    required this.summary,
    required this.shortWatch,
  });

  bool get hasAssets => assets.isNotEmpty;

  bool get hasNews => news.isNotEmpty;

  bool get hasData => hasAssets || hasNews;
}

String formatMarketPrice(double value) {
  if (value.abs() >= 1000) {
    return NumberFormat('#,##0.00', 'en_US').format(value);
  }

  if (value.abs() >= 1) {
    return NumberFormat('#,##0.00', 'en_US').format(value);
  }

  if (value.abs() >= 0.01) {
    return NumberFormat('#,##0.0000', 'en_US').format(value);
  }

  return NumberFormat('#,##0.000000', 'en_US').format(value);
}

String truncateText(String value, {int maxLength = 140}) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }

  return '${normalized.substring(0, maxLength).trimRight()}...';
}
