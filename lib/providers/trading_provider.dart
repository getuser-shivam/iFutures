import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../trading/algo_strategy.dart';
import '../trading/ai_strategy.dart';
import '../trading/manual_strategy.dart';
import '../trading/strategy.dart';
import '../constants/symbols.dart';
import '../models/kline.dart';
import '../models/ai_provider.dart';
import '../models/ai_service_status.dart';
import '../models/manual_order.dart';
import '../models/trade.dart';
import '../models/risk_settings.dart';
import '../models/position.dart';
import '../models/live_order.dart';
import '../models/binance_account_status.dart';
import '../models/connection_status.dart';
import '../models/price_alert.dart';
import '../models/market_analysis.dart';
import '../models/ai_trade_direction_mode.dart';
import '../models/order_book_snapshot.dart';
import '../models/strategy_console_entry.dart';
import '../models/strategy_mode.dart';
import '../models/protection_status.dart';

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

final tradingClientOwnerIdProvider = FutureProvider<String>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  return settings.getOrCreateTradingClientOwnerId();
});

final binanceApiProvider = FutureProvider<BinanceApiService>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);

  final apiKey = await settings.getApiKey() ?? '';
  final apiSecret = await settings.getApiSecret() ?? '';
  final isTestnet = settings.getIsTestnet();
  final blockWebLiveCredentials = kIsWeb && !isTestnet;
  if (blockWebLiveCredentials && (apiKey.isNotEmpty || apiSecret.isNotEmpty)) {
    await settings.setApiKey('');
    await settings.setApiSecret('');
  }

  return BinanceApiService(
    apiKey: blockWebLiveCredentials ? '' : apiKey,
    apiSecret: blockWebLiveCredentials ? '' : apiSecret,
    isTestnet: isTestnet,
    allowOrderMutations: !kIsWeb || isTestnet,
  );
});

final binanceWsProvider = FutureProvider<BinanceWebSocketService>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  return BinanceWebSocketService(isTestnet: settings.getIsTestnet());
});

final symbolRulesProvider = FutureProvider.family<BinanceSymbolRules?, String>((
  ref,
  symbol,
) async {
  final api = await ref.watch(binanceApiProvider.future);
  return api.getSymbolRules(symbol);
});

final aiStrategyProvider = FutureProvider.family<AiStrategy, String>((
  ref,
  symbol,
) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  var provider = aiProviderFromKey(settings.getAiProvider());
  var aiKey = await settings.getAiApiKey();

  if (!kIsWeb &&
      (aiKey == null || aiKey.isEmpty) &&
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
    tradeDirectionMode: aiTradeDirectionModeFromKey(
      settings.getAiTradeDirectionMode(),
    ),
    leverage: settings.getAiLeverage() ?? settings.getRiskLeverage(),
    maxInvestmentUsdt: settings.getAiInvestmentUsdt(),
    takeProfitPercent: settings.getRiskTakeProfitPercent(),
    stopLossPercent: settings.getRiskStopLossPercent(),
  );
});

final aiServiceStatusProvider = FutureProvider.family<AiServiceStatus, String>((
  ref,
  symbol,
) async {
  final strategy = await ref.watch(aiStrategyProvider(symbol).future);
  return strategy.verifyConnection();
});

class CurrentStrategyNotifier extends StateNotifier<TradingStrategy?> {
  final Ref _ref;
  final SettingsService _settings;
  final Completer<TradingStrategy> _readyCompleter =
      Completer<TradingStrategy>();
  Future<void> _modeChangeTail = Future<void>.value();
  int _modeRequestGeneration = 0;

  CurrentStrategyNotifier(this._ref, this._settings) : super(null) {
    unawaited(_load());
  }

  Future<TradingStrategy> get ready => _readyCompleter.future;

  Future<void> _load() async {
    final restoreGeneration = _modeRequestGeneration;
    try {
      await _settings.init();
      final symbol = await _ref.read(selectedSymbolReadyProvider.future);
      final mode = _settings.getLastStrategyMode();
      final strategy = await _buildStrategy(mode, symbol);
      if (restoreGeneration != _modeRequestGeneration) return;
      state = strategy;
      _completeReady(strategy);
    } catch (error, stackTrace) {
      if (restoreGeneration == _modeRequestGeneration &&
          !_readyCompleter.isCompleted) {
        _readyCompleter.completeError(error, stackTrace);
      }
    }
  }

  Future<void> setMode(
    StrategyMode mode, {
    String? symbol,
    bool persist = true,
  }) {
    final requestGeneration = ++_modeRequestGeneration;
    final previous = _modeChangeTail;
    final operation = () async {
      try {
        await previous;
      } catch (_) {
        // A later user choice must still be able to run after a failed choice.
      }
      await _applyModeRequest(
        mode,
        symbol: symbol,
        persist: persist,
        requestGeneration: requestGeneration,
      );
    }();
    _modeChangeTail = operation;
    return operation;
  }

  Future<void> _applyModeRequest(
    StrategyMode mode, {
    required String? symbol,
    required bool persist,
    required int requestGeneration,
  }) async {
    await _settings.init();
    if (requestGeneration != _modeRequestGeneration) return;
    final String activeSymbol = symbol ?? _ref.read(selectedSymbolProvider);
    final nextStrategy = await _buildStrategy(mode, activeSymbol);
    if (requestGeneration != _modeRequestGeneration) return;

    if (persist) {
      await _settings.setLastStrategyMode(mode);
    }
    if (requestGeneration != _modeRequestGeneration) return;
    state = nextStrategy;
    _completeReady(nextStrategy);
  }

  Future<TradingStrategy> _buildStrategy(
    StrategyMode mode,
    String activeSymbol,
  ) async {
    return switch (mode) {
      StrategyMode.manual => ManualStrategy(),
      StrategyMode.algo => RsiStrategy(
        period: _settings.getRsiPeriod(),
        overbought: _settings.getRsiOverbought(),
        oversold: _settings.getRsiOversold(),
      ),
      StrategyMode.ai => await _ref.read(
        aiStrategyProvider(activeSymbol).future,
      ),
    };
  }

  void _completeReady(TradingStrategy strategy) {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete(strategy);
    }
  }

  Future<void> refreshFromSettings({String? symbol}) async {
    final mode = switch (state) {
      AiStrategy() => StrategyMode.ai,
      RsiStrategy() => StrategyMode.algo,
      _ => StrategyMode.manual,
    };
    await setMode(mode, symbol: symbol, persist: false);
  }
}

class SelectedSymbolNotifier extends StateNotifier<String> {
  final SettingsService _settings;
  final Completer<String> _readyCompleter = Completer<String>();
  Future<void> _selectionTail = Future<void>.value();
  int _selectionGeneration = 0;

  SelectedSymbolNotifier(this._settings) : super(defaultSymbol) {
    unawaited(_load());
  }

  Future<String> get ready => _readyCompleter.future;

  Future<void> _load() async {
    final restoreGeneration = _selectionGeneration;
    try {
      await _settings.init();
      if (restoreGeneration != _selectionGeneration) return;
      final saved = _settings.getLastSelectedSymbol();
      final normalized = saved?.trim().toUpperCase();
      if (normalized != null && normalized.isNotEmpty) {
        state = normalized;
      }
      _completeReady(state);
    } catch (error, stackTrace) {
      if (restoreGeneration == _selectionGeneration &&
          !_readyCompleter.isCompleted) {
        _readyCompleter.completeError(error, stackTrace);
      }
    }
  }

  Future<void> setSymbol(String value) {
    final normalized = value.trim().toUpperCase();
    final requestGeneration = ++_selectionGeneration;
    state = normalized;
    _completeReady(normalized);

    final previous = _selectionTail;
    final operation = () async {
      try {
        await previous;
      } catch (_) {
        // A later explicit selection must survive an earlier storage failure.
      }
      await _settings.init();
      if (requestGeneration != _selectionGeneration) return;
      await _settings.setLastSelectedSymbol(normalized);
    }();
    _selectionTail = operation;
    return operation;
  }

  void _completeReady(String symbol) {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete(symbol);
    }
  }
}

final selectedSymbolProvider =
    StateNotifierProvider<SelectedSymbolNotifier, String>((ref) {
      final settings = ref.watch(settingsServiceProvider);
      return SelectedSymbolNotifier(settings);
    });

final selectedSymbolReadyProvider = FutureProvider<String>((ref) {
  return ref.watch(selectedSymbolProvider.notifier).ready;
});

final currentStrategyReadyProvider = FutureProvider<TradingStrategy>((ref) {
  final current = ref.watch(currentStrategyProvider);
  return current == null
      ? ref.watch(currentStrategyProvider.notifier).ready
      : Future<TradingStrategy>.value(current);
});

final symbolListProvider = FutureProvider<List<String>>((ref) async {
  await ref.watch(settingsInitProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  final stored = settings.getSymbolList();
  if (stored != null && stored.isNotEmpty) {
    return normalizeSymbolList(
      stored,
      requiredSymbols: [...coreTradingSymbols, truusdtSymbol],
    );
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
    investmentUsdt:
        settings.getRiskInvestmentUsdt() ?? settings.getRiskTradeQuantity(),
    targetProfitUsdt: settings.getRiskTargetProfitUsdt(),
    maxLossUsdt: settings.getRiskMaxLossUsdt(),
    leverage: settings.getRiskLeverage(),
    cooldownMinutes: settings.getRiskCooldownMinutes(),
    protectionPauseMinutes: settings.getRiskProtectionPauseMinutes(),
    maxConsecutiveLosses: settings.getRiskMaxConsecutiveLosses(),
    maxDrawdownPercent: settings.getRiskMaxDrawdownPercent(),
  );
});

final marketAnalysisProvider = FutureProvider<MarketAnalysisSnapshot>((
  ref,
) async {
  final service = ref.watch(marketAnalysisServiceProvider);
  return service.loadSnapshot();
});

final currentStrategyProvider =
    StateNotifierProvider<CurrentStrategyNotifier, TradingStrategy?>((ref) {
      final settings = ref.watch(settingsServiceProvider);
      return CurrentStrategyNotifier(ref, settings);
    });

final currentStrategyModeProvider = Provider<StrategyMode>((ref) {
  final strategy = ref.watch(currentStrategyProvider);
  return switch (strategy) {
    AiStrategy() => StrategyMode.ai,
    RsiStrategy() => StrategyMode.algo,
    _ => StrategyMode.manual,
  };
});

final tradingEngineProvider = FutureProvider.autoDispose
    .family<TradingEngine, String>((ref, symbol) async {
      await ref.watch(selectedSymbolReadyProvider.future);
      final strategy = await ref.watch(currentStrategyReadyProvider.future);
      final api = await ref.watch(binanceApiProvider.future);
      final ws = await ref.watch(binanceWsProvider.future);
      final history = ref.watch(tradeHistoryServiceProvider);
      final riskSettings = await ref.watch(riskSettingsProvider.future);
      final trackedSymbols = await ref.watch(symbolListProvider.future);
      final clientOrderOwnerId = await ref.watch(
        tradingClientOwnerIdProvider.future,
      );
      final engine = TradingEngine(
        apiService: api,
        wsService: ws,
        tradeHistoryService: history,
        strategy: strategy,
        riskSettings: riskSettings,
        symbol: symbol,
        trackedSymbols: trackedSymbols,
        clientOrderOwnerId: clientOrderOwnerId,
      );

      ref.onDispose(() {
        engine.dispose();
      });

      return engine;
    });

enum RuntimeDisarmState { noEngine, disarmed, failed }

class RuntimeDisarmResult {
  final RuntimeDisarmState state;
  final Object? error;

  const RuntimeDisarmResult._(this.state, [this.error]);

  const RuntimeDisarmResult.noEngine() : this._(RuntimeDisarmState.noEngine);

  const RuntimeDisarmResult.disarmed() : this._(RuntimeDisarmState.disarmed);

  const RuntimeDisarmResult.failed(Object error)
    : this._(RuntimeDisarmState.failed, error);

  bool get canProceed => state != RuntimeDisarmState.failed;
}

class TradingRuntimeSafety {
  final Ref _ref;

  const TradingRuntimeSafety(this._ref);

  /// Confirms that an already-created engine has stopped and reconciled its
  /// owned working entries before provider-backed runtime dependencies change.
  /// Manual and one-click maker entries use the same engine, so this check is
  /// deliberately independent of the auto-running UI flag.
  Future<RuntimeDisarmResult> disarmBeforeRuntimeChange({
    required String symbol,
    required String reason,
  }) async {
    final engineAsync = _ref.read(tradingEngineProvider(symbol));
    TradingEngine? engine = engineAsync.valueOrNull;
    final markedRunning = _ref.read(isBotRunningProvider(symbol));

    if (engine == null && markedRunning) {
      try {
        engine = await _ref.read(tradingEngineProvider(symbol).future);
      } catch (error) {
        return RuntimeDisarmResult.failed(error);
      }
    }
    if (engine == null) {
      return const RuntimeDisarmResult.noEngine();
    }

    try {
      await engine.disarmTrading(reason: reason);
      _ref.read(isBotRunningProvider(symbol).notifier).state = false;
      return const RuntimeDisarmResult.disarmed();
    } catch (error) {
      return RuntimeDisarmResult.failed(error);
    }
  }
}

final tradingRuntimeSafetyProvider = Provider<TradingRuntimeSafety>((ref) {
  return TradingRuntimeSafety(ref);
});

final tickerStreamProvider = StreamProvider.autoDispose.family<dynamic, String>(
  (ref, symbol) async* {
    final ws = await ref.watch(binanceWsProvider.future);
    yield* ws.subscribeToTicker(symbol);
  },
);

final klineStreamProvider = StreamProvider.autoDispose
    .family<List<Kline>, String>((ref, symbol) async* {
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

final tradeStreamProvider = StreamProvider.autoDispose
    .family<List<Trade>, String>((ref, symbol) async* {
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

final accountTradeStreamProvider = StreamProvider.autoDispose
    .family<List<Trade>, String>((ref, symbol) async* {
      final engineAsync = ref.watch(tradingEngineProvider(symbol));

      if (engineAsync is AsyncData<TradingEngine>) {
        final engine = engineAsync.value;
        yield engine.accountTrades;
        if (!engine.isStreaming) {
          await engine.startMarketData();
        }
        yield* engine.accountTradeStream;
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

final positionStreamProvider = StreamProvider.autoDispose
    .family<Position?, String>((ref, symbol) async* {
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

final orderBookSnapshotProvider = StreamProvider.autoDispose
    .family<OrderBookSnapshot?, String>((ref, symbol) async* {
      final engineAsync = ref.watch(tradingEngineProvider(symbol));

      if (engineAsync is AsyncData<TradingEngine>) {
        final engine = engineAsync.value;
        yield engine.orderBookSnapshot;
        if (!engine.isStreaming) {
          await engine.startMarketData();
        }
        yield* engine.orderBookSnapshotStream;
      } else {
        yield null;
      }
    });

final protectionStatusProvider = StreamProvider.autoDispose
    .family<ProtectionStatus, String>((ref, symbol) async* {
      final engineAsync = ref.watch(tradingEngineProvider(symbol));

      if (engineAsync is AsyncData<TradingEngine>) {
        final engine = engineAsync.value;
        yield engine.lastProtectionStatus;
        if (!engine.isStreaming) {
          await engine.startMarketData();
        }
        yield* engine.protectionStatusStream;
      } else {
        yield const ProtectionStatus.ready();
      }
    });

final pendingManualOrderStreamProvider = StreamProvider.autoDispose
    .family<List<PendingManualOrder>, String>((ref, symbol) async* {
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

final openOrderStreamProvider = StreamProvider.autoDispose
    .family<List<LiveOrder>, String>((ref, symbol) async* {
      final engineAsync = ref.watch(tradingEngineProvider(symbol));

      if (engineAsync is AsyncData<TradingEngine>) {
        final engine = engineAsync.value;
        yield engine.openOrders;
        if (!engine.isStreaming) {
          await engine.startMarketData();
        }
        yield* engine.openOrderStream;
      } else {
        yield const <LiveOrder>[];
      }
    });

final signalStreamProvider = StreamProvider.autoDispose
    .family<TradingSignal?, String>((ref, symbol) async* {
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

final decisionPlanStreamProvider = StreamProvider.autoDispose
    .family<StrategyTradePlan?, String>((ref, symbol) async* {
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

final consoleLogStreamProvider = StreamProvider.autoDispose
    .family<List<StrategyConsoleEntry>, String>((ref, symbol) async* {
      final engineAsync = ref.watch(tradingEngineProvider(symbol));

      if (engineAsync is AsyncData<TradingEngine>) {
        final engine = engineAsync.value;
        yield engine.consoleEntries;
        if (!engine.isStreaming) {
          await engine.startMarketData();
        }
        yield* engine.consoleLogStream;
      } else {
        yield const <StrategyConsoleEntry>[];
      }
    });

final connectionStatusProvider = StreamProvider.autoDispose
    .family<ConnectionStatus, String>((ref, symbol) async* {
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

final binanceAccountStatusProvider = StreamProvider.autoDispose
    .family<BinanceAccountStatus, String>((ref, symbol) async* {
      final engineAsync = ref.watch(tradingEngineProvider(symbol));

      if (engineAsync is AsyncData<TradingEngine>) {
        final engine = engineAsync.value;
        yield engine.lastBinanceAccountStatus;
        if (!engine.isStreaming) {
          await engine.startMarketData();
        }
        yield* engine.binanceAccountStatusStream;
      } else {
        yield const BinanceAccountStatus.notConfigured();
      }
    });

final isBotRunningProvider = StateProvider.family<bool, String>(
  (ref, symbol) => false,
);
