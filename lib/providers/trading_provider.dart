import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import '../services/settings_service.dart';
import '../trading/trading_engine.dart';
import '../trading/ai_strategy.dart';
import '../trading/algo_strategy.dart';
import '../trading/strategy.dart';
import '../models/kline.dart';
import '../models/trade.dart';
import '../models/risk_settings.dart';
import '../models/position.dart';
import '../models/connection_status.dart';

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

const _defaultSymbol = 'GALAUSDT';

class SelectedSymbolNotifier extends StateNotifier<String> {
  final SettingsService _settings;

  SelectedSymbolNotifier(this._settings) : super(_defaultSymbol) {
    _load();
  }

  Future<void> _load() async {
    await _settings.init();
    final saved = _settings.getLastSelectedSymbol();
    if (state == _defaultSymbol && saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setSymbol(String value) async {
    state = value;
    await _settings.setLastSelectedSymbol(value);
  }
}

final selectedSymbolProvider = StateNotifierProvider<SelectedSymbolNotifier, String>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  return SelectedSymbolNotifier(settings);
});

final riskSettingsProvider = FutureProvider<RiskSettings>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  return RiskSettings(
    stopLossPercent: settings.getRiskStopLossPercent(),
    takeProfitPercent: settings.getRiskTakeProfitPercent(),
    tradeQuantity: settings.getRiskTradeQuantity(),
  );
});

final currentStrategyProvider = StateProvider<TradingStrategy?>((ref) {
  return RsiStrategy();
});

final tradingEngineProvider = FutureProvider.family<TradingEngine, String>((ref, symbol) async {
  final api = await ref.watch(binanceApiProvider.future);
  final ws = await ref.watch(binanceWsProvider.future);
  final riskSettings = await ref.watch(riskSettingsProvider.future);
  final strategy = ref.watch(currentStrategyProvider);
  
  if (strategy == null) {
    throw Exception('Strategy not initialized');
  }
  
  final engine = TradingEngine(
    apiService: api,
    wsService: ws,
    strategy: strategy,
    riskSettings: riskSettings,
    symbol: symbol,
  );
  
  ref.onDispose(() {
    engine.dispose();
  });
  
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
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
    yield* engine.klineStream;
  } else {
    yield [];
  }
});

final tradeStreamProvider = StreamProvider.family<List<Trade>, String>((ref, symbol) async* {
  final engineAsync = ref.watch(tradingEngineProvider(symbol));
  
  if (engineAsync is AsyncData<TradingEngine>) {
    final engine = engineAsync.value;
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
    yield* engine.tradeStream;
  } else {
    yield [];
  }
});

final positionStreamProvider = StreamProvider.family<Position?, String>((ref, symbol) async* {
  final engineAsync = ref.watch(tradingEngineProvider(symbol));

  if (engineAsync is AsyncData<TradingEngine>) {
    final engine = engineAsync.value;
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
    yield* engine.positionStream;
  } else {
    yield null;
  }
});

final connectionStatusProvider = StreamProvider.family<ConnectionStatus, String>((ref, symbol) async* {
  final engineAsync = ref.watch(tradingEngineProvider(symbol));

  if (engineAsync is AsyncData<TradingEngine>) {
    final engine = engineAsync.value;
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
    yield* engine.connectionStream;
  } else {
    yield ConnectionStatus.disconnected();
  }
});

final isBotRunningProvider = StateProvider.family<bool, String>((ref, symbol) => false);
