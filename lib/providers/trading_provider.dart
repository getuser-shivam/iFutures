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
  print('DEBUG: Initializing SettingsService...');
  final settings = ref.watch(settingsServiceProvider);
  await settings.init();
  print('DEBUG: SettingsService initialized.');
});

final binanceApiProvider = FutureProvider<BinanceApiService>((ref) async {
  print('DEBUG: Loading BinanceApiService...');
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  
  final apiKey = await settings.getApiKey() ?? '';
  final apiSecret = await settings.getApiSecret() ?? '';
  
  print('DEBUG: BinanceApiService loaded with isTestnet: ${settings.getIsTestnet()}');
  return BinanceApiService(
    apiKey: apiKey,
    apiSecret: apiSecret,
    isTestnet: settings.getIsTestnet(),
  );
});

final binanceWsProvider = FutureProvider<BinanceWebSocketService>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  return BinanceWebSocketService(isTestnet: settings.getIsTestnet());
});

final aiStrategyProvider = FutureProvider<AiStrategy>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  return AiStrategy(
    apiUrl: settings.getAiUrl(),
    apiKey: 'your_ai_key',
  );
});

final currentStrategyProvider = StateProvider<TradingStrategy?>((ref) {
  final aiStrategy = ref.watch(aiStrategyProvider).valueOrNull;
  return aiStrategy;
});

final tradingEngineProvider = FutureProvider.family<TradingEngine, String>((ref, symbol) async {
  print('DEBUG: Creating TradingEngine for $symbol...');
  final api = await ref.watch(binanceApiProvider.future);
  final ws = await ref.watch(binanceWsProvider.future);
  final strategy = ref.watch(currentStrategyProvider);
  
  if (strategy == null) {
    throw Exception('Strategy not initialized');
  }
  
  final engine = TradingEngine(
    apiService: api,
    wsService: ws,
    strategy: strategy,
    symbol: symbol,
  );
  
  ref.onDispose(() {
    print('DEBUG: Disposing TradingEngine for $symbol');
    engine.dispose();
  });
  
  print('DEBUG: TradingEngine created for $symbol');
  return engine;
});

final tickerStreamProvider = StreamProvider.family<dynamic, String>((ref, symbol) async* {
  final ws = await ref.watch(binanceWsProvider.future);
  yield* ws.subscribeToTicker(symbol);
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
