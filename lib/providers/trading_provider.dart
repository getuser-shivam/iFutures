import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import '../trading/engine.dart';
import '../trading/algo_strategy.dart';
import '../trading/ai_strategy.dart';
import '../trading/strategy.dart';

final apiServiceProvider = Provider<BinanceApiService>((ref) {
  // These should be loaded from secure storage in a real app
  return BinanceApiService(
    apiKey: 'YOUR_API_KEY',
    apiSecret: 'YOUR_API_SECRET',
    isTestnet: true,
  );
});

final wsServiceProvider = Provider<BinanceWebSocketService>((ref) {
  return BinanceWebSocketService();
});

final tradingEngineProvider = Provider<TradingEngine>((ref) {
  final api = ref.watch(apiServiceProvider);
  final ws = ref.watch(wsServiceProvider);
  return TradingEngine(api: api, ws: ws);
});

final currentStrategyProvider = StateProvider<TradingStrategy>((ref) {
  return RsiStrategy();
});

final tickerStreamProvider = StreamProvider.family<dynamic, String>((ref, symbol) {
  final ws = ref.watch(wsServiceProvider);
  return ws.subscribeToTicker(symbol);
});

final klineStreamProvider = StreamProvider.family<dynamic, String>((ref, symbol) {
  final ws = ref.watch(wsServiceProvider);
  return ws.subscribeToKlines(symbol);
});
