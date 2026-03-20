import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/symbols.dart';
import '../models/market_analysis.dart';

class MarketAnalysisService {
  static const _marketDataUrl =
      'https://r.jina.ai/http://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=bitcoin,ethereum,binancecoin,solana';

  static const _newsFeeds = [
    _NewsFeed(feedLabel: 'BTC', query: 'bitcoin'),
    _NewsFeed(feedLabel: 'ETH', query: 'ethereum'),
    _NewsFeed(feedLabel: 'BNB', query: 'binance coin'),
    _NewsFeed(feedLabel: 'SOL', query: 'solana'),
  ];

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      responseType: ResponseType.plain,
    ),
  );

  Future<MarketAnalysisSnapshot> loadSnapshot() async {
    Map<String, Map<String, dynamic>> marketData = {};
    try {
      marketData = await _loadMarketData();
    } catch (_) {
      marketData = {};
    }

    final assets = marketWatchlistSymbols
        .map((symbol) {
          try {
            return _buildAssetSnapshot(symbol, marketData);
          } catch (_) {
            return null;
          }
        })
        .whereType<MarketAssetSnapshot>()
        .toList();

    final newsFutures = _newsFeeds.map((feed) async {
      try {
        return await _loadNewsFeed(feed);
      } catch (_) {
        return <MarketNewsItem>[];
      }
    });

    final news = _dedupeNews(
      (await Future.wait(newsFutures)).expand((items) => items).toList(),
    );

    if (assets.isEmpty && news.isEmpty) {
      throw StateError('Market analysis unavailable');
    }

    final bias = _deriveBias(assets, news);
    final summary = _buildSummary(assets, news, bias);
    final shortWatch = _buildShortWatch(assets, news, bias);

    return MarketAnalysisSnapshot(
      updatedAt: DateTime.now(),
      assets: assets,
      news: news,
      bias: bias,
      summary: summary,
      shortWatch: shortWatch,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadMarketData() async {
    final response = await _dio.get<String>(_marketDataUrl);
    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw StateError('Empty market payload');
    }

    final decoded = jsonDecode(_extractProxyContent(raw));
    if (decoded is! List) {
      throw StateError('Unexpected market payload');
    }

    final marketData = <String, Map<String, dynamic>>{};
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) {
          marketData[id] = item;
        }
      }
    }

    if (marketData.isEmpty) {
      throw StateError('No market data found');
    }

    return marketData;
  }

  MarketAssetSnapshot _buildAssetSnapshot(
    String symbol,
    Map<String, Map<String, dynamic>> marketData,
  ) {
    final data = marketData[_coinGeckoIdForSymbol(symbol)];
    if (data == null) {
      throw StateError('Missing market data for $symbol');
    }

    return MarketAssetSnapshot(
      symbol: symbol,
      displayName: _displayName(symbol),
      lastPrice: _parseDouble(data['current_price']) ?? 0,
      changePercent: _parseDouble(data['price_change_percentage_24h']) ?? 0,
      highPrice: _parseDouble(data['high_24h']) ?? 0,
      lowPrice: _parseDouble(data['low_24h']) ?? 0,
      volume: _parseDouble(data['total_volume']) ?? 0,
      updatedAt: _parseDateTime(data['last_updated']) ?? DateTime.now(),
    );
  }

  Future<List<MarketNewsItem>> _loadNewsFeed(_NewsFeed feed) async {
    final response = await _dio.get<String>(_googleNewsFeedUrl(feed.query));
    final body = response.data;
    if (body == null || body.isEmpty) {
      return const [];
    }

    final items = <MarketNewsItem>[];
    for (final item in _extractRssItems(body)) {
      final title = _cleanXmlText(_extractTag(item, 'title') ?? '');
      final link = _cleanXmlText(_extractTag(item, 'link') ?? '');
      final summary = truncateText(
        _cleanXmlText(_extractTag(item, 'description') ?? ''),
        maxLength: 160,
      );

      if (title.isEmpty || link.isEmpty) {
        continue;
      }

      items.add(
        MarketNewsItem(
          source: 'Google News',
          feedLabel: feed.feedLabel,
          title: title,
          summary: summary.isEmpty ? title : summary,
          link: link,
        ),
      );

      if (items.length >= 3) {
        break;
      }
    }

    return items;
  }

  MarketBias _deriveBias(
    List<MarketAssetSnapshot> assets,
    List<MarketNewsItem> news,
  ) {
    if (assets.isEmpty) {
      return MarketBias.neutral;
    }

    final averageChange =
        assets.map((asset) => asset.changePercent).reduce((a, b) => a + b) /
        assets.length;
    final newsScore = _scoreNews(news);
    final combinedScore = averageChange + (newsScore * 0.45);

    if (combinedScore >= 0.75) {
      return MarketBias.bullish;
    }
    if (combinedScore <= -0.75) {
      return MarketBias.bearish;
    }
    return MarketBias.neutral;
  }

  String _buildSummary(
    List<MarketAssetSnapshot> assets,
    List<MarketNewsItem> news,
    MarketBias bias,
  ) {
    final btc = _maybeAssetBySymbol(assets, 'BTCUSDT');
    final eth = _maybeAssetBySymbol(assets, 'ETHUSDT');
    final leaders = assets.where((asset) => asset.changePercent >= 0).length;
    final laggards = assets.length - leaders;
    final avgChange = assets.isEmpty
        ? 0.0
        : assets.map((asset) => asset.changePercent).reduce((a, b) => a + b) /
              assets.length;
    final trend = avgChange >= 0 ? 'positive' : 'soft';
    final headlineCount = news.length;

    final marketSentence = switch (bias) {
      MarketBias.bullish =>
        'Breadth is leaning bullish, with $leaders of ${assets.length} major coins green.',
      MarketBias.bearish =>
        'Breadth is weak, with $laggards of ${assets.length} major coins red.',
      MarketBias.neutral =>
        'Breadth is mixed, so the market does not yet have a clean directional edge.',
    };

    final btcEthSentence = switch ((btc, eth)) {
      (MarketAssetSnapshot btc, MarketAssetSnapshot eth) =>
        'BTC ${btc.changeLabel} at ${btc.priceLabel} and ETH ${eth.changeLabel} at ${eth.priceLabel}.',
      (MarketAssetSnapshot btc, null) =>
        'BTC ${btc.changeLabel} at ${btc.priceLabel}. ETH data was unavailable this refresh.',
      (null, MarketAssetSnapshot eth) =>
        'ETH ${eth.changeLabel} at ${eth.priceLabel}. BTC data was unavailable this refresh.',
      _ => 'BTC and ETH data were unavailable this refresh.',
    };
    final newsSentence = headlineCount == 0
        ? 'Fresh headlines were unavailable, so this snapshot is price-led.'
        : 'The latest pulse is built from $headlineCount crypto headlines.';

    return '$btcEthSentence $marketSentence Momentum is $trend, and $newsSentence';
  }

  String _buildShortWatch(
    List<MarketAssetSnapshot> assets,
    List<MarketNewsItem> news,
    MarketBias bias,
  ) {
    final btc = _maybeAssetBySymbol(assets, 'BTCUSDT');
    final eth = _maybeAssetBySymbol(assets, 'ETHUSDT');
    final bearishHeadlines =
        _scoreNews(news) < 0 ||
        news.any((item) => item.title.toLowerCase().contains('sell'));

    if (bias == MarketBias.bearish ||
        ((btc?.changePercent ?? 0) < 0 && (eth?.changePercent ?? 0) < 0)) {
      return 'Short watch: look for a breakdown and failed retest before leaning on the downside.';
    }

    if (bearishHeadlines) {
      return 'Short watch: the news mix is heavier, but let price confirm with a lower high or lost support.';
    }

    return 'Short watch: the tape is mixed, so wait for a clear rejection or loss of support before shorting.';
  }

  MarketAssetSnapshot? _maybeAssetBySymbol(
    List<MarketAssetSnapshot> assets,
    String symbol,
  ) {
    for (final asset in assets) {
      if (asset.symbol == symbol) {
        return asset;
      }
    }
    return null;
  }

  String _googleNewsFeedUrl(String query) {
    return Uri.https('news.google.com', '/rss/search', {
      'q': '$query when:1d',
      'hl': 'en-US',
      'gl': 'US',
      'ceid': 'US:en',
    }).toString();
  }

  String _coinGeckoIdForSymbol(String symbol) {
    return switch (symbol) {
      'BTCUSDT' => 'bitcoin',
      'ETHUSDT' => 'ethereum',
      'BNBUSDT' => 'binancecoin',
      'SOLUSDT' => 'solana',
      _ => symbol.toLowerCase().replaceAll('usdt', ''),
    };
  }

  double? _parseDouble(Object? value) {
    return double.tryParse(value?.toString() ?? '');
  }

  DateTime? _parseDateTime(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '');
  }

  String _extractProxyContent(String raw) {
    const marker = 'Markdown Content:';
    final index = raw.indexOf(marker);
    if (index == -1) {
      return raw.trim();
    }

    var payload = raw.substring(index + marker.length).trim();
    if (payload.startsWith('```')) {
      payload = payload.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      if (payload.endsWith('```')) {
        payload = payload.substring(0, payload.length - 3).trim();
      }
    }

    return payload;
  }

  List<String> _extractRssItems(String body) {
    return RegExp(
      r'<item\b[^>]*>(.*?)</item>',
      dotAll: true,
    ).allMatches(body).map((match) => match.group(1) ?? '').toList();
  }

  String? _extractTag(String item, String tag) {
    final match = RegExp(
      '<$tag(?:\\s[^>]*)?>(.*?)</$tag>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(item);
    if (match == null) {
      return null;
    }
    return match.group(1);
  }

  String _cleanXmlText(String value) {
    var text = value.trim();
    if (text.startsWith('<![CDATA[') && text.endsWith(']]>')) {
      text = text.substring(9, text.length - 3);
    }

    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&apos;', '\'');
    text = text.replaceAll('&#39;', '\'');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<MarketNewsItem> _dedupeNews(List<MarketNewsItem> news) {
    final seen = <String>{};
    final deduped = <MarketNewsItem>[];
    for (final item in news) {
      final key = '${item.title.toLowerCase()}|${item.link.toLowerCase()}';
      if (seen.add(key)) {
        deduped.add(item);
      }
    }

    return deduped.take(4).toList();
  }

  double _scoreNews(List<MarketNewsItem> news) {
    if (news.isEmpty) {
      return 0;
    }

    var score = 0.0;
    for (final item in news) {
      final text = '${item.title} ${item.summary}'.toLowerCase();
      if (_containsAny(text, _positiveKeywords)) {
        score += 1;
      }
      if (_containsAny(text, _negativeKeywords)) {
        score -= 1;
      }
    }

    return score / news.length;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  String _displayName(String symbol) {
    return symbol.replaceAll('USDT', '');
  }
}

class _NewsFeed {
  final String feedLabel;
  final String query;

  const _NewsFeed({required this.feedLabel, required this.query});
}

const List<String> _positiveKeywords = [
  'inflow',
  'inflows',
  'etf',
  'approval',
  'launch',
  'adoption',
  'staking',
  'upgrade',
  'accumulation',
  'buy',
  'bullish',
];

const List<String> _negativeKeywords = [
  'outflow',
  'outflows',
  'hack',
  'lawsuit',
  'ban',
  'sell-off',
  'selloff',
  'crash',
  'liquidation',
  'bearish',
];
