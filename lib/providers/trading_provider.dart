import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import '../services/backtest_service.dart';
import '../services/market_analysis_service.dart';
import '../services/settings_service.dart';
import '../services/price_alert_service.dart';
import '../services/trade_csv_export_service.dart';
import '../services/trade_history_service.dart';
import '../trading/trading_engine.dart';
import '../trading/ai_strategy.dart';
import '../trading/manual_strategy.dart';
import '../trading/strategy.dart';
import '../constants/symbols.dart';
import '../models/kline.dart';
import '../models/ai_provider.dart';
import '../models/manual_order.dart';
import '../models/trade.dart';
import '../models/risk_settings.dart';
import '../models/position.dart';
import '../models/connection_status.dart';
import '../models/price_alert.dart';
import '../models/market_analysis.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final tradeHistoryServiceProvider = Provider<TradeHistoryService>((ref) {
  return TradeHistoryService();
});

final tradeCsvExportServiceProvider = Provider<TradeCsvExportService>((ref) {
  return TradeCsvExportService();
});

final backtestServiceProvider = Provider<BacktestService>((ref) {
  return const BacktestService();
});

final marketAnalysisServiceProvider = Provider<MarketAnalysisService>((ref) {
  return MarketAnalysisService();
});

final priceAlertServiceProvider = Provider<PriceAlertService>((ref) {
  return PriceAlertService();
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

final aiStrategyProvider = FutureProvider.family<AiStrategy, String>((
  ref,
  symbol,
) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  var provider = aiProviderFromKey(settings.getAiProvider());
  var aiKey = await settings.getAiApiKey();

  if ((aiKey == null || aiKey.isEmpty) &&
      provider != AiProvider.customPromptApi) {
    await settings.importAiConfigFromAutomation();
    provider = aiProviderFromKey(settings.getAiProvider());
    aiKey = await settings.getAiApiKey();
  }

  return AiStrategy(
    apiUrl: settings.getAiUrl(),
    apiKey: aiKey,
    provider: provider,
    model: settings.getAiModel(),
    symbolLabel: symbol,
    longBiasPrice: settings.getAiLongBiasPrice(),
    shortBiasPrice: settings.getAiShortBiasPrice(),
    longOrderType: ManualOrderType.values.byName(settings.getAiLongOrderType()),
    shortOrderType: ManualOrderType.values.byName(
      settings.getAiShortOrderType(),
    ),
    leverage: settings.getRiskLeverage(),
    takeProfitPercent: settings.getRiskTakeProfitPercent(),
    stopLossPercent: settings.getRiskStopLossPercent(),
  );
});

class SelectedSymbolNotifier extends StateNotifier<String> {
  final SettingsService _settings;

  SelectedSymbolNotifier(this._settings) : super(defaultSymbol) {
    _load();
  }

  Future<void> _load() async {
    await _settings.init();
    final saved = _settings.getLastSelectedSymbol();
    final normalized = saved?.trim().toUpperCase();
    if (state == defaultSymbol && normalized != null && normalized.isNotEmpty) {
      state = normalized;
    }
  }

  Future<void> setSymbol(String value) async {
    final normalized = value.trim().toUpperCase();
    state = normalized;
    await _settings.setLastSelectedSymbol(normalized);
  }
}

final selectedSymbolProvider =
    StateNotifierProvider<SelectedSymbolNotifier, String>((ref) {
      final settings = ref.watch(settingsServiceProvider);
      return SelectedSymbolNotifier(settings);
    });

final symbolListProvider = FutureProvider<List<String>>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  final stored = settings.getSymbolList();
  if (stored != null && stored.isNotEmpty) {
    return normalizeSymbolList(stored, requiredSymbols: [triausdtSymbol]);
  }
  return defaultSymbols;
});

final riskSettingsProvider = FutureProvider<RiskSettings>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  return RiskSettings(
    stopLossPercent: settings.getRiskStopLossPercent(),
    takeProfitPercent: settings.getRiskTakeProfitPercent(),
    tradeQuantity: settings.getRiskTradeQuantity(),
    leverage: settings.getRiskLeverage(),
  );
});

final marketAnalysisProvider = FutureProvider<MarketAnalysisSnapshot>((
  ref,
) async {
  final service = ref.watch(marketAnalysisServiceProvider);
  return service.loadSnapshot();
});

final currentStrategyProvider = StateProvider<TradingStrategy?>((ref) {
  return ManualStrategy();
});

final tradingEngineProvider = FutureProvider.family<TradingEngine, String>((
  ref,
  symbol,
) async {
  final api = await ref.watch(binanceApiProvider.future);
  final ws = await ref.watch(binanceWsProvider.future);
  final history = ref.watch(tradeHistoryServiceProvider);
  final riskSettings = await ref.watch(riskSettingsProvider.future);
  final strategy = ref.watch(currentStrategyProvider);

  if (strategy == null) {
    throw Exception('Strategy not initialized');
  }

  final engine = TradingEngine(
    apiService: api,
    wsService: ws,
    tradeHistoryService: history,
    strategy: strategy,
    riskSettings: riskSettings,
    symbol: symbol,
  );

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});

final tickerStreamProvider = StreamProvider.family<dynamic, String>((
  ref,
  symbol,
) async* {
  final ws = await ref.watch(binanceWsProvider.future);
  yield* ws.subscribeToTicker(symbol);
});

final klineStreamProvider = StreamProvider.family<List<Kline>, String>((
  ref,
  symbol,
) async* {
  final engineAsync = ref.watch(tradingEngineProvider(symbol));

  if (engineAsync is AsyncData<TradingEngine>) {
    final engine = engineAsync.value;
    yield engine.klines;
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
    yield* engine.klineStream;
  } else {
    yield [];
  }
});

final tradeStreamProvider = StreamProvider.family<List<Trade>, String>((
  ref,
  symbol,
) async* {
  final engineAsync = ref.watch(tradingEngineProvider(symbol));

  if (engineAsync is AsyncData<TradingEngine>) {
    final engine = engineAsync.value;
    yield engine.trades;
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
    yield* engine.tradeStream;
  } else {
    yield [];
  }
});

final priceAlertsProvider = FutureProvider.family<List<PriceAlert>, String>((
  ref,
  symbol,
) async {
  final service = ref.watch(priceAlertServiceProvider);
  return service.loadAlerts(symbol);
});

final positionStreamProvider = StreamProvider.family<Position?, String>((
  ref,
  symbol,
) async* {
  final engineAsync = ref.watch(tradingEngineProvider(symbol));

  if (engineAsync is AsyncData<TradingEngine>) {
    final engine = engineAsync.value;
    yield engine.openPosition;
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
    yield* engine.positionStream;
  } else {
    yield null;
  }
});

final pendingManualOrderStreamProvider =
    StreamProvider.family<List<PendingManualOrder>, String>((
      ref,
      symbol,
    ) async* {
      final engineAsync = ref.watch(tradingEngineProvider(symbol));

      if (engineAsync is AsyncData<TradingEngine>) {
        final engine = engineAsync.value;
        yield engine.pendingManualOrders;
        if (!engine.isStreaming) {
          await engine.startMarketData();
        }
        yield* engine.pendingOrderStream;
      } else {
        yield const <PendingManualOrder>[];
      }
    });

final signalStreamProvider = StreamProvider.family<TradingSignal?, String>((
  ref,
  symbol,
) async* {
  final engineAsync = ref.watch(tradingEngineProvider(symbol));

  if (engineAsync is AsyncData<TradingEngine>) {
    final engine = engineAsync.value;
    yield engine.lastSignal;
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
    yield* engine.signalStream;
  } else {
    yield null;
  }
});

final decisionPlanStreamProvider =
    StreamProvider.family<StrategyTradePlan?, String>((ref, symbol) async* {
      final engineAsync = ref.watch(tradingEngineProvider(symbol));

      if (engineAsync is AsyncData<TradingEngine>) {
        final engine = engineAsync.value;
        yield engine.lastDecisionPlan;
        if (!engine.isStreaming) {
          await engine.startMarketData();
        }
        yield* engine.decisionPlanStream;
      } else {
        yield null;
      }
    });

final connectionStatusProvider =
    StreamProvider.family<ConnectionStatus, String>((ref, symbol) async* {
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

final isBotRunningProvider = StateProvider.family<bool, String>(
  (ref, symbol) => false,
);
