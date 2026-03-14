import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import '../services/settings_service.dart';
import '../trading/trading_engine.dart';
import '../trading/ai_strategy.dart';
import '../trading/algo_strategy.dart';
import '../trading/strategy.dart';
import '../models/kline.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final settingsInitProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  await settings.init();
});

final binanceApiProvider = FutureProvider<BinanceApiService>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  
  final apiKey = await settings.getApiKey() ?? '';
  final apiSecret = await settings.getApiSecret() ?? '';
  
  return BinanceApiService(
    apiKey: apiKey,
    apiSecret: apiSecret,
    isTestnet: settings.getIsTestnet(),
  );
});

final binanceWsProvider = Provider<BinanceWebSocketService>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  // Note: In a real app, you might want to wait for settingsInitProvider here too
  // but if the UI waits for it overall, it might be fine.
  return BinanceWebSocketService(isTestnet: settings.getIsTestnet());
});

final aiStrategyProvider = Provider<AiStrategy>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  return AiStrategy(
    apiUrl: settings.getAiUrl(),
    apiKey: 'your_ai_key',
  );
});

final currentStrategyProvider = StateProvider<TradingStrategy>((ref) {
  return ref.read(aiStrategyProvider);
});

final tradingEngineProvider = FutureProvider.family<TradingEngine, String>((ref, symbol) async {
  final api = await ref.watch(binanceApiProvider.future);
  final ws = ref.watch(binanceWsProvider);
  final strategy = ref.watch(currentStrategyProvider);
  
  final engine = TradingEngine(
    apiService: api,
    wsService: ws,
    strategy: strategy,
    symbol: symbol,
  );
  
  ref.onDispose(() => engine.dispose());
  
  return engine;
});

final tickerStreamProvider = StreamProvider.family<dynamic, String>((ref, symbol) {
  final ws = ref.watch(binanceWsProvider);
  return ws.subscribeToTicker(symbol);
});

final klineStreamProvider = StreamProvider.family<List<Kline>, String>((ref, symbol) async* {
  final engineAsync = ref.watch(tradingEngineProvider(symbol));
  
  if (engineAsync is AsyncData<TradingEngine>) {
    final engine = engineAsync.value;
    if (!engine.isRunning) {
      engine.start();
    }
    yield* engine.klineStream;
  } else {
    yield [];
  }
});

final isBotRunningProvider = StateProvider<bool>((ref) => false);
