import 'dart:async';
import '../models/kline.dart';
import '../models/manual_order.dart';
import '../models/trade.dart';
import '../models/risk_settings.dart';
import '../models/position.dart';
import '../models/live_order.dart';
import '../models/binance_account_status.dart';
import '../models/connection_status.dart';
import '../models/ai_trade_outcome_snapshot.dart';
import '../models/order_book_snapshot.dart';
import '../models/order_book_trend_snapshot.dart';
import '../models/protection_status.dart';
import '../models/strategy_console_entry.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import '../services/order_book_analyzer.dart';
import '../services/order_book_trend_analyzer.dart';
import '../services/trade_outcome_analyzer.dart';
import '../services/trade_history_service.dart';
import 'strategy.dart';

class TradingEngine {
  final BinanceApiService apiService;
  final BinanceWebSocketService wsService;
  final TradeHistoryService tradeHistoryService;
  final TradingStrategy strategy;
  final RiskSettings riskSettings;
  final String symbol;
  final List<String> trackedSymbols;
  final String clientOrderOwnerId;
  final Duration ambiguousEntryMinimumQuarantine;
  final int ambiguousEntryNotFoundConfirmations;
  final Duration userDataRetryBaseDelay;
  final Duration userDataRetryMaxDelay;

  List<Kline> _klines = [];
  List<Trade> _trades = [];
  List<Trade> _accountTrades = [];
  List<PendingManualOrder> _pendingManualOrders = [];
  List<LiveOrder> _openOrders = [];
  List<StrategyConsoleEntry> _consoleEntries = [];
  bool _isAutoTradingEnabled = false;
  bool _isStreaming = false;
  bool _hasLoadedTrades = false;
  bool _manualOverrideActive = false;
  int _manualOrderSequence = 0;
  Timer? _exchangeSyncTimer;
  Position? _openPosition;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _userDataSubscription;
  Timer? _userDataKeepAliveTimer;
  Timer? _userDataSyncDebounceTimer;
  Timer? _userDataRetryTimer;
  String? _userDataListenKey;
  bool _isStartingUserDataStream = false;
  int _userDataRetryAttempt = 0;
  Timer? _connectionTimer;
  DateTime? _lastMessageAt;
  int? _lastLatencyMs;
  BinanceAccountStatus _binanceAccountStatus;
  BinanceFuturesPositionMode _futuresPositionMode =
      BinanceFuturesPositionMode.unknown;
  double? _walletBalance;
  double? _availableBalance;
  int? _openPositionCount;
  OrderBookSnapshot? _orderBookSnapshot;
  List<OrderBookSnapshot> _orderBookHistory = [];
  DateTime? _orderBookSyncedAt;
  DateTime? _cooldownUntil;
  DateTime? _protectionLockUntil;
  String? _protectionLockReason;
  double? _activeTakeProfitPrice;
  double? _activeStopLossPrice;
  bool _isRiskExitInFlight = false;
  DateTime? _riskExitUncertainUntil;
  bool _isProtectionOrderSyncInFlight = false;
  bool _isStrategyEvaluationInFlight = false;
  bool _isExchangeSyncInFlight = false;
  Completer<void>? _exchangeSyncCompleter;
  bool _isOrderSubmissionInFlight = false;
  bool _activeSubmissionMayOpenExposure = false;
  Completer<void>? _orderSubmissionCompleter;
  bool _isDisarming = false;
  final Map<String, _AmbiguousEntryIntent> _ambiguousEntryIntents = {};
  int _executionGeneration = 0;
  bool _ownsActivePosition = false;
  bool _hasOwnedEntryIntent = false;
  ProtectionStatus _protectionStatus = const ProtectionStatus.ready();
  TradingSignal? _lastSignal;
  StrategyTradePlan? _lastDecisionPlan;
  String? _lastLoggedPlanFingerprint;
  String? _lastExecutionBlockFingerprint;
  String? _lastLiveStrategyFingerprint;

  final _klineController = StreamController<List<Kline>>.broadcast();
  final _tradeController = StreamController<List<Trade>>.broadcast();
  final _accountTradeController = StreamController<List<Trade>>.broadcast();
  final _positionController = StreamController<Position?>.broadcast();
  final _protectionController = StreamController<ProtectionStatus>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  final _binanceAccountController =
      StreamController<BinanceAccountStatus>.broadcast();
  final _signalController = StreamController<TradingSignal?>.broadcast();
  final _decisionPlanController =
      StreamController<StrategyTradePlan?>.broadcast();
  final _consoleLogController =
      StreamController<List<StrategyConsoleEntry>>.broadcast();
  final _pendingOrderController =
      StreamController<List<PendingManualOrder>>.broadcast();
  final _openOrderController = StreamController<List<LiveOrder>>.broadcast();
  final _orderBookSnapshotController =
      StreamController<OrderBookSnapshot?>.broadcast();

  Stream<List<Kline>> get klineStream => _klineController.stream;
  Stream<List<Trade>> get tradeStream => _tradeController.stream;
  Stream<List<Trade>> get accountTradeStream => _accountTradeController.stream;
  Stream<Position?> get positionStream => _positionController.stream;
  Stream<ProtectionStatus> get protectionStatusStream =>
      _protectionController.stream;
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  Stream<BinanceAccountStatus> get binanceAccountStatusStream =>
      _binanceAccountController.stream;
  Stream<TradingSignal?> get signalStream => _signalController.stream;
  Stream<StrategyTradePlan?> get decisionPlanStream =>
      _decisionPlanController.stream;
  Stream<List<StrategyConsoleEntry>> get consoleLogStream =>
      _consoleLogController.stream;
  Stream<List<PendingManualOrder>> get pendingOrderStream =>
      _pendingOrderController.stream;
  Stream<List<LiveOrder>> get openOrderStream => _openOrderController.stream;
  Stream<OrderBookSnapshot?> get orderBookSnapshotStream =>
      _orderBookSnapshotController.stream;

  TradingEngine({
    required this.apiService,
    required this.wsService,
    required this.tradeHistoryService,
    required this.strategy,
    required this.riskSettings,
    required this.symbol,
    List<String> trackedSymbols = const [],
    String clientOrderOwnerId = 'local000',
    this.ambiguousEntryMinimumQuarantine = const Duration(seconds: 10),
    this.ambiguousEntryNotFoundConfirmations = 3,
    this.userDataRetryBaseDelay = const Duration(seconds: 1),
    this.userDataRetryMaxDelay = const Duration(seconds: 30),
  }) : _binanceAccountStatus = BinanceAccountStatus.notConfigured(
         isTestnet: apiService.isTestnet,
       ),
       clientOrderOwnerId = _normalizeClientOrderOwnerId(clientOrderOwnerId),
       trackedSymbols = _normalizeTrackedSymbols(symbol, trackedSymbols);

  bool get isStreaming => _isStreaming;
  bool get isTradingEnabled => _isAutoTradingEnabled;
  bool get isManualOverrideActive => _manualOverrideActive;
  Position? get openPosition => _openPosition;
  List<Kline> get klines => _klines;
  List<Trade> get trades => _trades;
  List<Trade> get accountTrades => List.unmodifiable(_accountTrades);
  List<LiveOrder> get openOrders => List.unmodifiable(_openOrders);
  double? get walletBalance => _walletBalance;
  double? get availableBalance => _availableBalance;
  int? get openPositionCount => _openPositionCount;
  OrderBookSnapshot? get orderBookSnapshot => _orderBookSnapshot;
  DateTime? get orderBookSyncedAt => _orderBookSyncedAt;
  List<OrderBookSnapshot> get orderBookHistory =>
      List.unmodifiable(_orderBookHistory);
  OrderBookTrendSnapshot? get orderBookTrendSnapshot =>
      OrderBookTrendAnalyzer.analyze(_orderBookHistory);
  List<AiTradeOutcomeSnapshot> get recentTradeOutcomes =>
      TradeOutcomeAnalyzer.analyze(
        _accountTrades.isNotEmpty ? _accountTrades : _trades,
      );
  ProtectionStatus get lastProtectionStatus => _protectionStatus;
  List<PendingManualOrder> get pendingManualOrders =>
      List.unmodifiable(_pendingManualOrders);
  List<StrategyConsoleEntry> get consoleEntries =>
      List.unmodifiable(_consoleEntries);
  TradingSignal? get lastSignal => _lastSignal;
  StrategyTradePlan? get lastDecisionPlan => _lastDecisionPlan;
  BinanceAccountStatus get lastBinanceAccountStatus => _binanceAccountStatus;
  bool get hasExchangeCredentials => apiService.hasCredentials;
  BinanceFuturesPositionMode get futuresPositionMode => _futuresPositionMode;

  Future<void> startMarketData() async {
    if (_isStreaming) return;
    _isStreaming = true;
    _logConsole('Starting market stream for $symbol using ${strategy.name}.');
    _positionController.add(_openPosition);
    _connectionController.add(ConnectionStatus.connecting());
    _signalController.add(_lastSignal);
    _decisionPlanController.add(_lastDecisionPlan);
    _consoleLogController.add(consoleEntries);
    _accountTradeController.add(accountTrades);
    _protectionController.add(_protectionStatus);
    _orderBookSnapshotController.add(_orderBookSnapshot);
    _emitPendingOrders();
    _emitOpenOrders();
    _emitBinanceAccountStatus(
      apiService.hasCredentials
          ? BinanceAccountStatus.checking(
              isTestnet: apiService.isTestnet,
              message:
                  'Checking ${apiService.isTestnet ? 'Binance demo' : 'Binance live'} account sync...',
            )
          : BinanceAccountStatus.notConfigured(
              isTestnet: apiService.isTestnet,
              message:
                  'Binance API credentials are not configured for this app yet.',
            ),
    );
    _startConnectionTicker();
    if (apiService.hasCredentials) {
      final syncedExchangeState = await _loadInitialAccountState();
      if (!syncedExchangeState) {
        _trades = [];
        _accountTrades = [];
        _openOrders = [];
        _openPosition = null;
        _clearPlanRiskTargets();
        _tradeController.add(_trades);
        _accountTradeController.add(_accountTrades);
        _positionController.add(_openPosition);
        _emitOpenOrders();
      } else {
        await _startUserDataStream();
      }
    } else {
      await _loadPersistedTrades();
    }

    // 1. Fetch historical data
    try {
      final historicalData = await apiService.getKlines(
        symbol: symbol,
        limit: 1440,
      );
      _klines = historicalData.map((e) => Kline.fromJson(e)).toList();
      _klineController.add(_klines);
      _logConsole('Loaded ${_klines.length} historical candles for $symbol.');
      if (_klines.isNotEmpty) {
        await _refreshOrderBookContextIfNeeded(force: true);
        await _evaluateStrategy();
      }
    } catch (e) {
      _logConsole(
        'Historical candles failed to load: $e',
        level: StrategyConsoleLevel.error,
      );
      print('Failed to fetch historical data: $e');
    }

    _startExchangeSyncTimer();

    // 2. Subscribe to real-time updates
    _wsSubscription = wsService
        .subscribeToKlines(
          symbol,
          onStatusChanged: _handleConnectionStatusUpdate,
        )
        .listen(
          (event) {
            _recordMessageTimestamp(event);
            final kline = Kline.fromWsJson(event);
            _updateKlines(kline);
            _checkRisk(kline.close);
            _processPendingManualOrders(kline.close);

            // If candle is closed, evaluate strategy regardless of auto execution
            if (event['k']['x'] == true) {
              _evaluateStrategy();
            }
          },
          onError: (e) {
            _logConsole(
              'WebSocket error: $e',
              level: StrategyConsoleLevel.error,
            );
            print('WS subscription error: $e');
            _isStreaming = false;
            _emitConnectionStatus(forceDisconnected: true);
          },
        );
  }

  Future<void> start() async {
    return startMarketData();
  }

  Future<void> enableTrading() async {
    _executionGeneration++;
    _isAutoTradingEnabled = true;
    _manualOverrideActive = false;
    _lastLiveStrategyFingerprint = null;
    _logConsole('Auto execution armed for ${strategy.name}.');
    if (!_isStreaming) {
      await startMarketData();
    }
  }

  void disableTrading({
    String reason = 'manual_stop',
    bool cancelWorkingEntries = true,
  }) {
    _executionGeneration++;
    _isAutoTradingEnabled = false;
    _manualOverrideActive = false;
    _lastLiveStrategyFingerprint = null;
    _logConsole(
      'Auto execution stopped (${reason.replaceAll('_', ' ')}).',
      level: StrategyConsoleLevel.warning,
    );
    if (cancelWorkingEntries &&
        _isExchangeSyncMode &&
        apiService.allowOrderMutations) {
      unawaited(
        cancelBotEntryOrders(reason: reason).catchError((Object error) {
          _logExecutionBlocked(
            'Could not cancel every iFutures entry while stopping: $error',
          );
          return 0;
        }),
      );
    }
  }

  Future<void> disarmTrading({String reason = 'manual_stop'}) async {
    if (_isDisarming) {
      throw StateError('STOP reconciliation is already in progress.');
    }
    _isDisarming = true;
    try {
      final entrySubmissionWasInFlight =
          _isOrderSubmissionInFlight && _activeSubmissionMayOpenExposure;
      final hadPositionBeforeDisarm = _openPosition != null;
      final submissionInFlight = _orderSubmissionCompleter?.future;
      disableTrading(reason: reason, cancelWorkingEntries: false);
      if (submissionInFlight != null) {
        _logConsole(
          'Waiting for the in-flight Binance request before completing STOP.',
          level: StrategyConsoleLevel.warning,
        );
        await submissionInFlight;
      }
      if (_isExchangeSyncMode && apiService.allowOrderMutations) {
        final syncedAfterSubmission = await _syncExchangeState();
        await cancelBotEntryOrders(reason: reason);
        final syncedAfterCancellation = await _syncExchangeState();

        if (entrySubmissionWasInFlight &&
            !hadPositionBeforeDisarm &&
            _openPosition != null &&
            _ownsActivePosition) {
          await _flattenUnexpectedPostDisarmPosition(reason: reason);
        }

        await _reconcileAmbiguousEntryIntents(
          accountSnapshotIsCurrent: syncedAfterCancellation,
        );
        if (_ambiguousEntryIntents.isNotEmpty) {
          throw StateError(
            'STOP is active, but Binance still has an unresolved entry intent (${_ambiguousEntryIntents.keys.join(', ')}). New entries remain quarantined; verify the account before leaving this symbol.',
          );
        }
        if (entrySubmissionWasInFlight &&
            !syncedAfterSubmission &&
            !syncedAfterCancellation) {
          throw StateError(
            'STOP is active, but Binance account reconciliation failed after an in-flight entry. Verify positions and orders before leaving this symbol.',
          );
        }
      }
    } finally {
      _isDisarming = false;
    }
  }

  Future<void> _flattenUnexpectedPostDisarmPosition({
    required String reason,
  }) async {
    final position = _openPosition;
    if (position == null || !_ownsActivePosition) {
      return;
    }
    if (!_beginOrderSubmission(
      mayOpenExposure: false,
      allowWhileDisarming: true,
    )) {
      throw StateError(
        'Could not flatten the post-STOP fill because another order submission started.',
      );
    }

    try {
      _logExecutionBlocked(
        'An iFutures entry filled while STOP was waiting. Sending a reduce-only market close so no unrequested exposure remains.',
      );
      final closeAction = position.isLong
          ? ManualOrderAction.closeLong
          : ManualOrderAction.closeShort;
      await _submitExchangeOrder(
        closeAction,
        quantity: position.quantity,
        orderType: ManualOrderType.market,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _syncExchangeState(logSuccess: true);
      if (_openPosition != null) {
        await _reconcileExchangeProtectionOrders(plan: _lastDecisionPlan);
        throw StateError(
          'The post-STOP entry close was sent but the position is still visible. Exchange stop protection was retained; verify Binance before leaving this symbol.',
        );
      }
      _logConsole(
        'Flattened the entry that filled during ${reason.replaceAll('_', ' ')}.',
        level: StrategyConsoleLevel.warning,
      );
    } catch (_) {
      await _syncExchangeState();
      if (_openPosition != null && _ownsActivePosition) {
        await _reconcileExchangeProtectionOrders(plan: _lastDecisionPlan);
      }
      rethrow;
    } finally {
      _finishOrderSubmission();
    }
  }

  void _updateKlines(Kline newKline) {
    if (_klines.isEmpty) {
      _klines.add(newKline);
    } else {
      final last = _klines.last;
      if (last.openTime == newKline.openTime) {
        _klines[_klines.length - 1] = newKline;
      } else {
        _klines.add(newKline);
        if (_klines.length > 1600) _klines.removeAt(0);
      }
    }
    _klineController.add(_klines);
  }

  Future<void> _evaluateStrategy() async {
    if (_isStrategyEvaluationInFlight) {
      _logConsole(
        'Strategy evaluation skipped because the previous evaluation is still running.',
        level: StrategyConsoleLevel.warning,
      );
      return;
    }
    _isStrategyEvaluationInFlight = true;
    try {
      await _refreshOrderBookContextIfNeeded();
      final orderBookTrendSnapshot = this.orderBookTrendSnapshot;
      final recentTradeOutcomes = this.recentTradeOutcomes;
      StrategyTradePlan? plan;
      final strategyCandidate = strategy;
      late final TradingSignal signal;
      if (strategyCandidate case final TradePlanningStrategy planningStrategy) {
        plan = await planningStrategy.buildTradePlan(
          _klines,
          symbol: symbol,
          riskSettings: riskSettings,
          context: StrategyAnalysisContext(
            openPosition: _openPosition,
            symbolTrades: List<Trade>.unmodifiable(_trades),
            accountTrades: List<Trade>.unmodifiable(_accountTrades),
            walletBalance: _walletBalance,
            availableBalance: _availableBalance,
            openPositionCount: _openPositionCount,
            accountSyncedAt: _binanceAccountStatus.lastSyncedAt,
            accountStatusMessage: _binanceAccountStatus.message,
            orderBookSnapshot: _orderBookSnapshot,
            orderBookSyncedAt: _orderBookSyncedAt,
            orderBookHistory: List<OrderBookSnapshot>.unmodifiable(
              _orderBookHistory,
            ),
            orderBookTrendSnapshot: orderBookTrendSnapshot,
            recentTradeOutcomes: recentTradeOutcomes,
          ),
        );
        signal = plan.signal;
      } else {
        signal = await strategy.evaluate(_klines);
      }
      _lastSignal = signal;
      _lastDecisionPlan = plan;
      _signalController.add(signal);
      _decisionPlanController.add(plan);
      _logPlan(plan, signal);
      if (!_isAutoTradingEnabled) return;

      if (signal == TradingSignal.buy) {
        await _handleSignal(PositionSide.long, plan: plan);
      } else if (signal == TradingSignal.sell) {
        await _handleSignal(PositionSide.short, plan: plan);
      }
    } catch (e) {
      _logConsole(
        'Strategy evaluation failed: $e',
        level: StrategyConsoleLevel.error,
      );
    } finally {
      _isStrategyEvaluationInFlight = false;
    }
  }

  Future<void> refreshStrategyPlan() async {
    await _ensureMarketData();
    _logConsole('Manual strategy refresh requested.');
    await _evaluateStrategy();
  }

  Future<void> _handleSignal(
    PositionSide desiredSide, {
    StrategyTradePlan? plan,
  }) async {
    await _handleSignalWithReason(desiredSide, 'strategy', plan: plan);
  }

  Future<void> manualEnterLong() async {
    final currentPrice = _klines.isNotEmpty ? _klines.last.close : null;
    await submitManualOrder(
      ManualOrderRequest(
        action: ManualOrderAction.openLong,
        orderType: ManualOrderType.market,
        quantity:
            riskSettings.resolveQuantity(currentPrice) ??
            riskSettings.tradeQuantity,
      ),
    );
  }

  Future<void> manualEnterShort() async {
    final currentPrice = _klines.isNotEmpty ? _klines.last.close : null;
    await submitManualOrder(
      ManualOrderRequest(
        action: ManualOrderAction.openShort,
        orderType: ManualOrderType.market,
        quantity:
            riskSettings.resolveQuantity(currentPrice) ??
            riskSettings.tradeQuantity,
      ),
    );
  }

  Future<void> manualClose() async {
    if (_openPosition == null) {
      return;
    }
    await submitManualOrder(
      ManualOrderRequest(
        action: _openPosition!.isLong
            ? ManualOrderAction.closeLong
            : ManualOrderAction.closeShort,
        orderType: ManualOrderType.market,
        quantity: _openPosition!.quantity,
      ),
    );
  }

  void takeManualControl() {
    _executionGeneration++;
    _isAutoTradingEnabled = false;
    _manualOverrideActive = true;
    _logConsole(
      'Manual override activated. Auto execution is paused.',
      level: StrategyConsoleLevel.warning,
    );
  }

  bool _beginOrderSubmission({
    required bool mayOpenExposure,
    bool allowWhileDisarming = false,
  }) {
    if (_isOrderSubmissionInFlight || (_isDisarming && !allowWhileDisarming)) {
      return false;
    }
    _isOrderSubmissionInFlight = true;
    _activeSubmissionMayOpenExposure = mayOpenExposure;
    _orderSubmissionCompleter = Completer<void>();
    return true;
  }

  void _finishOrderSubmission() {
    _isOrderSubmissionInFlight = false;
    _activeSubmissionMayOpenExposure = false;
    final completer = _orderSubmissionCompleter;
    _orderSubmissionCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<ManualOrderSubmissionResult> submitManualOrder(
    ManualOrderRequest request,
  ) async {
    if (_isDisarming) {
      return const ManualOrderSubmissionResult(
        accepted: false,
        message:
            'STOP is reconciling Binance orders. Wait for it to finish before submitting another order.',
      );
    }
    if (!_beginOrderSubmission(mayOpenExposure: request.action.isOpenAction)) {
      return const ManualOrderSubmissionResult(
        accepted: false,
        message: 'Another order is still being submitted. Wait for its result.',
      );
    }
    try {
      return await _submitManualOrderUnlocked(request);
    } finally {
      _finishOrderSubmission();
    }
  }

  Future<ManualOrderSubmissionResult> _submitManualOrderUnlocked(
    ManualOrderRequest request,
  ) async {
    final actualRouting = !_isExchangeSyncMode
        ? ManualOrderRoutingExpectation.paper
        : apiService.isTestnet
        ? ManualOrderRoutingExpectation.binanceDemo
        : ManualOrderRoutingExpectation.binanceLive;
    if (request.routingExpectation != null &&
        request.routingExpectation != actualRouting) {
      return const ManualOrderSubmissionResult(
        accepted: false,
        message:
            'Order routing changed while the ticket was open. Review the updated PAPER or BINANCE label, then submit again.',
      );
    }
    await _ensureMarketData();

    if (_isExchangeSyncMode) {
      final blockMessage = await _ensureLiveManualRoutingReady();
      if (blockMessage != null) {
        _logExecutionBlocked(blockMessage);
        return ManualOrderSubmissionResult(
          accepted: false,
          message: blockMessage,
        );
      }
      return _submitLiveManualOrder(request);
    }

    if (!request.quantity.isFinite || request.quantity <= 0) {
      return const ManualOrderSubmissionResult(
        accepted: false,
        message: 'Quantity must be greater than 0.',
      );
    }

    if (request.action.isCloseAction && !_hasMatchingPosition(request.action)) {
      return ManualOrderSubmissionResult(
        accepted: false,
        message:
            'No matching ${request.action.label.toLowerCase()} position is open.',
      );
    }

    takeManualControl();

    final currentPrice = _klines.last.close;
    switch (request.orderType) {
      case ManualOrderType.market:
        _executeImmediateManualAction(
          request.action,
          quantity: request.quantity,
          executionPrice: currentPrice,
          orderType: request.orderType,
          requestedPrice: currentPrice,
        );
        return ManualOrderSubmissionResult(
          accepted: true,
          message: '${request.action.label} market order executed.',
          executedOrders: 1,
        );
      case ManualOrderType.limit:
      case ManualOrderType.postOnly:
        final targetPrice = request.price;
        if (targetPrice == null || !targetPrice.isFinite || targetPrice <= 0) {
          return ManualOrderSubmissionResult(
            accepted: false,
            message: '${request.orderType.label} orders need a valid price.',
          );
        }

        if (request.orderType == ManualOrderType.postOnly &&
            _isMarketable(request.action, currentPrice, targetPrice)) {
          return ManualOrderSubmissionResult(
            accepted: false,
            message: 'Post Only rejected because it would execute immediately.',
          );
        }

        if (_shouldFillOrder(request.action, currentPrice, targetPrice)) {
          _executeImmediateManualAction(
            request.action,
            quantity: request.quantity,
            executionPrice: targetPrice,
            orderType: request.orderType,
            requestedPrice: targetPrice,
          );
          return ManualOrderSubmissionResult(
            accepted: true,
            message:
                '${request.action.label} ${request.orderType.label} filled.',
            executedOrders: 1,
          );
        }

        _queuePendingOrder(
          PendingManualOrder(
            id: _nextManualOrderId(),
            symbol: symbol,
            action: request.action,
            orderType: request.orderType,
            quantity: request.quantity,
            targetPrice: targetPrice,
            createdAt: DateTime.now(),
          ),
        );
        return ManualOrderSubmissionResult(
          accepted: true,
          message:
              '${request.action.label} ${request.orderType.label} queued at ${targetPrice.toStringAsFixed(6)}.',
          queuedOrders: 1,
        );
      case ManualOrderType.scaled:
        final startPrice = request.price;
        final endPrice = request.scaleEndPrice;
        if (startPrice == null ||
            endPrice == null ||
            !startPrice.isFinite ||
            !endPrice.isFinite ||
            startPrice <= 0 ||
            endPrice <= 0) {
          return const ManualOrderSubmissionResult(
            accepted: false,
            message: 'Scaled orders need a valid start and end price.',
          );
        }
        if (request.scaleSteps < 2) {
          return const ManualOrderSubmissionResult(
            accepted: false,
            message: 'Scaled orders need at least 2 steps.',
          );
        }

        final prices = _buildScaleTargets(
          startPrice,
          endPrice,
          request.scaleSteps,
        );
        final childQuantity = request.quantity / request.scaleSteps;
        var queued = 0;
        var executed = 0;

        for (var i = 0; i < prices.length; i++) {
          final targetPrice = prices[i];
          if (_shouldFillOrder(request.action, currentPrice, targetPrice)) {
            _executeImmediateManualAction(
              request.action,
              quantity: childQuantity,
              executionPrice: targetPrice,
              orderType: request.orderType,
              requestedPrice: targetPrice,
            );
            executed++;
          } else {
            _queuePendingOrder(
              PendingManualOrder(
                id: _nextManualOrderId(),
                symbol: symbol,
                action: request.action,
                orderType: request.orderType,
                quantity: childQuantity,
                targetPrice: targetPrice,
                createdAt: DateTime.now(),
                scaleIndex: i,
                scaleSteps: request.scaleSteps,
              ),
            );
            queued++;
          }
        }

        return ManualOrderSubmissionResult(
          accepted: true,
          message:
              '${request.action.label} scaled order submitted: $executed filled, $queued queued.',
          queuedOrders: queued,
          executedOrders: executed,
        );
    }
  }

  Future<String?> _ensureLiveManualRoutingReady() async {
    if (!_isExchangeSyncMode) {
      return null;
    }

    if (_binanceAccountStatus.state != BinanceAccountState.active) {
      await _syncExchangeState(logSuccess: true);
    }

    if (_binanceAccountStatus.state == BinanceAccountState.active) {
      if (_futuresPositionMode == BinanceFuturesPositionMode.hedge) {
        return 'Live execution is blocked in Hedge Mode because this app currently manages one position per symbol. Switch Binance Futures to One-way Mode after closing all positions and orders.';
      }
      if (_futuresPositionMode != BinanceFuturesPositionMode.oneWay) {
        return 'Live execution is blocked until Binance confirms One-way Position Mode. Refresh the account connection before placing an order.';
      }
      if (!apiService.allowOrderMutations) {
        return 'Live order mutations are blocked in this environment. Use the desktop app or Binance demo mode.';
      }
      return null;
    }

    return switch (_binanceAccountStatus.state) {
      BinanceAccountState.notConfigured =>
        'Binance API credentials are not configured for live manual orders.',
      BinanceAccountState.checking =>
        'Binance is still checking the account connection. Wait a few seconds and try again.',
      BinanceAccountState.limited =>
        _binanceAccountStatus.message ??
            'Binance is connected in read-only mode. Enable Futures trading permissions before sending manual orders.',
      BinanceAccountState.attentionRequired =>
        _binanceAccountStatus.message ??
            'Binance connection needs attention before sending manual orders.',
      BinanceAccountState.active => null,
    };
  }

  Future<ManualOrderSubmissionResult> _submitLiveManualOrder(
    ManualOrderRequest request,
  ) async {
    if (!request.quantity.isFinite || request.quantity <= 0) {
      return const ManualOrderSubmissionResult(
        accepted: false,
        message: 'Quantity must be greater than 0.',
      );
    }

    if (request.action.isCloseAction && !_hasMatchingPosition(request.action)) {
      return ManualOrderSubmissionResult(
        accepted: false,
        message:
            'No matching ${request.action.label.toLowerCase()} position is open.',
      );
    }

    if (request.action.isOpenAction && _openPosition != null) {
      return const ManualOrderSubmissionResult(
        accepted: false,
        message:
            'A position is already open for this symbol. Close it before starting a new one-click or manual entry.',
      );
    }
    if (request.action.isOpenAction && _ownedEntryOrders.isNotEmpty) {
      return ManualOrderSubmissionResult(
        accepted: false,
        message:
            'An iFutures entry order is already working for $symbol. Cancel or fill it before placing another entry.',
      );
    }
    if (request.action.isOpenAction) {
      final ambiguityMessage = await _ambiguousEntryBlockMessage();
      if (ambiguityMessage != null) {
        return ManualOrderSubmissionResult(
          accepted: false,
          message: ambiguityMessage,
        );
      }
      if (_hasOwnedEntryIntent) {
        return const ManualOrderSubmissionResult(
          accepted: false,
          message:
              'A previous iFutures entry is still reconciling with Binance. Wait for account sync before submitting another entry.',
        );
      }
    }

    if (request.action.isOpenAction) {
      final referencePrice =
          request.price ??
          _orderBookSnapshot?.midPrice ??
          (_klines.isNotEmpty ? _klines.last.close : null);
      final riskError = referencePrice == null
          ? 'A current market price is required before opening live exposure.'
          : _validateEntryRisk(
              quantity: request.quantity,
              entryPrice: referencePrice,
            );
      if (riskError != null) {
        return ManualOrderSubmissionResult(accepted: false, message: riskError);
      }
    }

    try {
      takeManualControl();
      _clearLocalPendingOrders();

      if (request.action.isOpenAction) {
        await apiService.setLeverage(
          symbol: symbol,
          leverage: riskSettings.leverage,
        );
      }

      switch (request.orderType) {
        case ManualOrderType.market:
          await _submitExchangeOrder(
            request.action,
            quantity: request.quantity,
            orderType: request.orderType,
          );
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await _syncExchangeState(logSuccess: true);
          _syncLiveRiskTargets(replaceExisting: request.action.isOpenAction);
          if (request.action.isOpenAction &&
              !await _ensureLiveStopProtectionOrFlatten()) {
            return const ManualOrderSubmissionResult(
              accepted: false,
              message:
                  'The entry was flattened because Binance stop protection could not be confirmed.',
            );
          }
          return ManualOrderSubmissionResult(
            accepted: true,
            message:
                '${request.action.label} market order sent to Binance ${apiService.isTestnet ? 'demo' : 'live'} futures.',
            executedOrders: 1,
          );
        case ManualOrderType.limit:
        case ManualOrderType.postOnly:
          final targetPrice = request.price;
          if (targetPrice == null ||
              !targetPrice.isFinite ||
              targetPrice <= 0) {
            return ManualOrderSubmissionResult(
              accepted: false,
              message: '${request.orderType.label} orders need a valid price.',
            );
          }

          await _submitExchangeOrder(
            request.action,
            quantity: request.quantity,
            orderType: request.orderType,
            price: targetPrice,
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await _syncExchangeState(logSuccess: true);
          _syncLiveRiskTargets(replaceExisting: request.action.isOpenAction);
          if (request.action.isOpenAction &&
              !await _ensureLiveStopProtectionOrFlatten()) {
            return const ManualOrderSubmissionResult(
              accepted: false,
              message:
                  'Any filled entry was flattened because Binance stop protection could not be confirmed.',
            );
          }
          return ManualOrderSubmissionResult(
            accepted: true,
            message:
                '${request.action.label} ${request.orderType.label.toLowerCase()} order submitted to Binance.',
            queuedOrders: 1,
          );
        case ManualOrderType.scaled:
          final startPrice = request.price;
          final endPrice = request.scaleEndPrice;
          if (startPrice == null ||
              endPrice == null ||
              !startPrice.isFinite ||
              !endPrice.isFinite ||
              startPrice <= 0 ||
              endPrice <= 0) {
            return const ManualOrderSubmissionResult(
              accepted: false,
              message: 'Scaled orders need a valid start and end price.',
            );
          }
          if (request.scaleSteps < 2) {
            return const ManualOrderSubmissionResult(
              accepted: false,
              message: 'Scaled orders need at least 2 steps.',
            );
          }

          final prices = _buildScaleTargets(
            startPrice,
            endPrice,
            request.scaleSteps,
          );
          final childQuantity = request.quantity / request.scaleSteps;

          for (final targetPrice in prices) {
            await _submitExchangeOrder(
              request.action,
              quantity: childQuantity,
              orderType: ManualOrderType.scaled,
              price: targetPrice,
            );
          }

          await Future<void>.delayed(const Duration(milliseconds: 500));
          await _syncExchangeState(logSuccess: true);
          _syncLiveRiskTargets(replaceExisting: request.action.isOpenAction);
          if (request.action.isOpenAction &&
              !await _ensureLiveStopProtectionOrFlatten()) {
            return const ManualOrderSubmissionResult(
              accepted: false,
              message:
                  'Any filled scaled entry was flattened because Binance stop protection could not be confirmed.',
            );
          }
          return ManualOrderSubmissionResult(
            accepted: true,
            message:
                '${request.action.label} scaled ladder submitted to Binance with ${request.scaleSteps} working orders.',
            queuedOrders: request.scaleSteps,
          );
      }
    } on BinanceRequestOutcomeUnknownException catch (error) {
      await _syncExchangeState();
      final clientId = error.clientOrderId ?? 'unknown';
      final message =
          'Binance did not confirm the final outcome for client order $clientId. Do not submit it again. Check Binance positions and working orders; the app will keep reconciling.';
      _logExecutionBlocked(message);
      return ManualOrderSubmissionResult(accepted: false, message: message);
    } on BinanceApiException catch (error) {
      final message =
          error.errorMessage ??
          'Binance rejected the manual order request (${error.statusCode}).';
      _logExecutionBlocked('Live manual order rejected: $message');
      return ManualOrderSubmissionResult(accepted: false, message: message);
    } catch (error) {
      final message = 'Live manual order failed: $error';
      _logExecutionBlocked(message);
      return ManualOrderSubmissionResult(accepted: false, message: message);
    }
  }

  Future<void> _submitExchangeOrder(
    ManualOrderAction action, {
    required double quantity,
    required ManualOrderType orderType,
    double? price,
    int retryCount = 0,
  }) async {
    if (!quantity.isFinite || quantity <= 0) {
      throw StateError('Quantity must be a finite value greater than 0.');
    }
    if (price != null && (!price.isFinite || price <= 0)) {
      throw StateError('Price must be a finite value greater than 0.');
    }
    final rules = await apiService.getSymbolRules(symbol);
    if (rules == null) {
      throw StateError(
        '$symbol is not listed in the selected Binance Futures environment.',
      );
    }
    if (!rules.isTradablePerpetual) {
      throw StateError(
        '$symbol is not an active Binance USD-M perpetual contract (status ${rules.status}, type ${rules.contractType}).',
      );
    }
    final isMarket = orderType == ManualOrderType.market;
    final normalizedQuantity = rules.normalizeQuantity(
      quantity,
      market: isMarket,
    );
    if (normalizedQuantity == null ||
        normalizedQuantity <= 0 ||
        rules.normalizeQuantity(quantity, market: isMarket) == null) {
      throw StateError(
        'Quantity is below Binance minimum size for $symbol. Increase the order size.',
      );
    }

    final normalizedPrice = price == null
        ? null
        : (rules.normalizePrice(price) ?? price);
    if (price != null && (normalizedPrice == null || normalizedPrice <= 0)) {
      throw StateError(
        'Price is below Binance minimum price increment for $symbol.',
      );
    }

    final referencePrice =
        normalizedPrice ??
        _orderBookSnapshot?.midPrice ??
        (_klines.isNotEmpty ? _klines.last.close : null);
    final minimumQuantity = referencePrice == null
        ? null
        : rules.minimumQuantityForPrice(referencePrice);
    final referenceNotionalPrice = referencePrice;
    if (minimumQuantity != null &&
        referenceNotionalPrice != null &&
        normalizedQuantity < minimumQuantity) {
      final minimumNotional = minimumQuantity * referenceNotionalPrice;
      throw StateError(
        'Quantity is below Binance minimum tradable size for $symbol. Need at least ${_formatQuantity(minimumQuantity)} ${symbol.toUpperCase()} (about ${_formatUsdt(minimumNotional)} notional).',
      );
    }

    final side = switch (action) {
      ManualOrderAction.openLong || ManualOrderAction.closeShort => 'BUY',
      ManualOrderAction.openShort || ManualOrderAction.closeLong => 'SELL',
    };
    final type = orderType == ManualOrderType.market ? 'MARKET' : 'LIMIT';
    final positionSide = _exchangePositionSideForAction(action);
    final reduceOnly = _exchangeReduceOnlyForAction(action);
    final timeInForce = switch (orderType) {
      ManualOrderType.market => null,
      ManualOrderType.limit || ManualOrderType.scaled => 'GTC',
      ManualOrderType.postOnly => 'GTX',
    };

    final clientOrderId = _nextClientOrderId(
      action.isOpenAction ? 'entry' : 'exit',
    );
    try {
      late final Map<String, dynamic> response;
      try {
        response = await apiService.placeOrder(
          symbol: symbol,
          side: side,
          type: type,
          quantity: rules.formatQuantity(normalizedQuantity, market: isMarket),
          price: normalizedPrice == null
              ? null
              : rules.formatPrice(normalizedPrice),
          timeInForce: timeInForce,
          positionSide: positionSide,
          reduceOnly: reduceOnly,
          newOrderRespType: orderType == ManualOrderType.market
              ? 'RESULT'
              : 'ACK',
          newClientOrderId: clientOrderId,
        );
      } on BinanceRequestOutcomeUnknownException {
        final reconciled = await _reconcileUnknownNormalOrder(clientOrderId);
        if (reconciled == null) {
          if (action.isOpenAction) {
            _quarantineAmbiguousEntryIntent(clientOrderId);
          }
          rethrow;
        }
        response = reconciled;
        _logConsole(
          'Recovered an uncertain Binance response by finding client order $clientOrderId. No duplicate order was sent.',
          level: StrategyConsoleLevel.warning,
        );
      }

      if (action.isOpenAction) {
        _trackEntryIntent(
          clientOrderId,
          orderId: response['orderId']?.toString(),
        );
        _hasOwnedEntryIntent = true;
        _ownsActivePosition = true;
      }

      final orderId = response['orderId'];
      _logConsole(
        'Submitted live ${orderType.label.toLowerCase()} ${action.label.toLowerCase()} order to Binance${orderId == null ? '' : ' (#$orderId)'} using ${_futuresPositionModeLabel.toLowerCase()} mode${positionSide == null ? '' : ' [$positionSide]'}.',
        level: StrategyConsoleLevel.success,
      );
    } on BinanceApiException catch (error) {
      if (retryCount == 0 && _isPositionModeMismatch(error)) {
        final previousMode = _futuresPositionMode;
        await _refreshFuturesPositionMode(logChange: true);
        if (_futuresPositionMode != previousMode) {
          _logConsole(
            'Retrying Binance order after refreshing futures mode to ${_futuresPositionModeLabel}.',
            level: StrategyConsoleLevel.warning,
          );
        }
        return _submitExchangeOrder(
          action,
          quantity: quantity,
          orderType: orderType,
          price: price,
          retryCount: retryCount + 1,
        );
      }
      rethrow;
    }
  }

  String get _futuresPositionModeLabel => switch (_futuresPositionMode) {
    BinanceFuturesPositionMode.oneWay => 'One-way',
    BinanceFuturesPositionMode.hedge => 'Hedge',
    BinanceFuturesPositionMode.unknown => 'Unknown',
  };

  String? _exchangePositionSideForAction(ManualOrderAction action) {
    return switch (_futuresPositionMode) {
      BinanceFuturesPositionMode.oneWay => null,
      BinanceFuturesPositionMode.hedge =>
        action.positionSide == PositionSide.long ? 'LONG' : 'SHORT',
      BinanceFuturesPositionMode.unknown => throw StateError(
        'Binance Futures position mode is unknown; order routing is blocked.',
      ),
    };
  }

  bool? _exchangeReduceOnlyForAction(ManualOrderAction action) {
    if (!action.isCloseAction) {
      return null;
    }
    return switch (_futuresPositionMode) {
      BinanceFuturesPositionMode.oneWay => true,
      BinanceFuturesPositionMode.hedge => null,
      BinanceFuturesPositionMode.unknown => throw StateError(
        'Binance Futures position mode is unknown; reduce-only routing is blocked.',
      ),
    };
  }

  Future<Map<String, dynamic>?> _reconcileUnknownNormalOrder(
    String clientOrderId,
  ) async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 400),
      Duration(milliseconds: 900),
    ];
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      try {
        return await apiService.getOrderByClientOrderId(
          symbol: symbol,
          origClientOrderId: clientOrderId,
        );
      } on BinanceApiException catch (error) {
        if (error.errorCode != -2013) {
          return null;
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _quarantineAmbiguousEntryIntent(String clientOrderId) {
    _trackEntryIntent(clientOrderId);
    _hasOwnedEntryIntent = true;
    _logExecutionBlocked(
      'Entry intent $clientOrderId is quarantined until Binance proves whether it exists. New entries are blocked.',
    );
  }

  void _trackEntryIntent(String clientOrderId, {String? orderId}) {
    final intent = _ambiguousEntryIntents.putIfAbsent(
      clientOrderId,
      () => _AmbiguousEntryIntent(
        clientOrderId: clientOrderId,
        createdAt: DateTime.now(),
      ),
    );
    if (orderId != null && orderId.isNotEmpty) {
      intent.orderId = orderId;
    }
  }

  Future<String?> _ambiguousEntryBlockMessage() async {
    if (_ambiguousEntryIntents.isEmpty) {
      return null;
    }
    await _reconcileAmbiguousEntryIntents();
    if (_ambiguousEntryIntents.isEmpty) {
      return null;
    }
    final ids = _ambiguousEntryIntents.keys.join(', ');
    return 'A previous Binance entry is still working or unresolved ($ids). New entries remain blocked until reconciliation completes.';
  }

  Future<void> _reconcileAmbiguousEntryIntents({
    bool accountSnapshotIsCurrent = false,
  }) async {
    if (_ambiguousEntryIntents.isEmpty || !apiService.hasCredentials) {
      return;
    }

    for (final intent in List<_AmbiguousEntryIntent>.of(
      _ambiguousEntryIntents.values,
    )) {
      try {
        final payload = await apiService.getOrderByClientOrderId(
          symbol: symbol,
          origClientOrderId: intent.clientOrderId,
        );
        final status = '${payload['status'] ?? ''}'.trim().toUpperCase();
        final orderId = payload['orderId']?.toString();
        if (orderId != null && orderId.isNotEmpty) {
          intent.orderId = orderId;
        }
        intent.notFoundConfirmations = 0;
        final executedQuantity =
            _asDouble(payload['executedQty'] ?? payload['cumQty']) ?? 0;
        if (executedQuantity > intent.executedQuantity) {
          intent.executedQuantity = executedQuantity;
        }
        final isWorking =
            status.isEmpty ||
            status == 'NEW' ||
            status == 'PENDING_NEW' ||
            status == 'PARTIALLY_FILLED';
        final isTerminal =
            status == 'FILLED' ||
            status == 'CANCELED' ||
            status == 'CANCELLED' ||
            status == 'REJECTED' ||
            status == 'EXPIRED' ||
            status == 'EXPIRED_IN_MATCH';
        final hasExecution = intent.executedQuantity > 0 || status == 'FILLED';
        final statusChanged = intent.lastStatus != status;
        intent.lastStatus = status;

        if (isWorking) {
          _hasOwnedEntryIntent = true;
          if (_openPosition != null) {
            _ownsActivePosition = true;
          }
          if (statusChanged) {
            _logConsole(
              'Tracked Binance entry ${intent.clientOrderId} is ${status.isEmpty ? 'not fully acknowledged yet' : status}. New entries remain blocked.',
              level: StrategyConsoleLevel.warning,
            );
          }
          continue;
        }

        if (hasExecution) {
          _hasOwnedEntryIntent = true;
          if (_openPosition != null) {
            _ownsActivePosition = true;
            if (isTerminal) {
              _ambiguousEntryIntents.remove(intent.clientOrderId);
            }
            continue;
          }

          if (isTerminal && accountSnapshotIsCurrent) {
            intent.flatAfterExecutionConfirmations += 1;
            final oldEnough =
                DateTime.now().difference(intent.createdAt) >=
                ambiguousEntryMinimumQuarantine;
            final requiredConfirmations =
                ambiguousEntryNotFoundConfirmations < 1
                ? 1
                : ambiguousEntryNotFoundConfirmations;
            if (oldEnough &&
                intent.flatAfterExecutionConfirmations >=
                    requiredConfirmations) {
              _ambiguousEntryIntents.remove(intent.clientOrderId);
              _clearOwnedEntryIntentIfSafe();
              _logConsole(
                'Binance entry ${intent.clientOrderId} executed but repeated current account snapshots are flat; its intent lock was cleared.',
                level: StrategyConsoleLevel.warning,
              );
            }
          }
          continue;
        }

        if (isTerminal) {
          _ambiguousEntryIntents.remove(intent.clientOrderId);
          _clearOwnedEntryIntentIfSafe();
          _logConsole(
            'Binance confirmed entry ${intent.clientOrderId} is $status with no execution. New entries may resume after account sync.',
            level: StrategyConsoleLevel.warning,
          );
        }
      } on BinanceApiException catch (error) {
        if (error.errorCode != -2013) {
          continue;
        }
        intent.notFoundConfirmations += 1;
        final oldEnough =
            DateTime.now().difference(intent.createdAt) >=
            ambiguousEntryMinimumQuarantine;
        final requiredConfirmations = ambiguousEntryNotFoundConfirmations < 1
            ? 1
            : ambiguousEntryNotFoundConfirmations;
        final appearsInSnapshot = _openOrders.any(
          (order) =>
              order.clientOrderId == intent.clientOrderId ||
              (intent.orderId != null && order.orderId == intent.orderId),
        );
        if (accountSnapshotIsCurrent &&
            oldEnough &&
            intent.notFoundConfirmations >= requiredConfirmations &&
            !appearsInSnapshot &&
            _openPosition == null) {
          _ambiguousEntryIntents.remove(intent.clientOrderId);
          _clearOwnedEntryIntentIfSafe();
          _logConsole(
            'Binance repeatedly confirmed that quarantined entry ${intent.clientOrderId} does not exist; the entry quarantine was cleared.',
            level: StrategyConsoleLevel.warning,
          );
        }
      } catch (_) {
        // Transport/read failures are not proof that an ambiguous entry is absent.
      }
    }
  }

  void _clearOwnedEntryIntentIfSafe() {
    if (_ambiguousEntryIntents.isEmpty &&
        _openPosition == null &&
        _ownedEntryOrders.isEmpty) {
      _hasOwnedEntryIntent = false;
    }
  }

  bool _isPositionModeMismatch(BinanceApiException error) {
    final message = '${error.errorMessage ?? error.body}'.toLowerCase();
    return error.errorCode == -4061 ||
        message.contains("position side does not match user's setting");
  }

  void _clearLocalPendingOrders() {
    if (_pendingManualOrders.isEmpty) {
      return;
    }
    _pendingManualOrders.clear();
    _emitPendingOrders();
  }

  Future<void> _ensureMarketData() async {
    if (!_isStreaming) {
      await startMarketData();
    }
  }

  Future<void> _handleSignalWithReason(
    PositionSide desiredSide,
    String reason, {
    StrategyTradePlan? plan,
  }) async {
    final protectionMessage = _activeProtectionMessage();
    if (reason == 'strategy' && protectionMessage != null) {
      _logExecutionBlocked(
        'Protection engine is active: $protectionMessage New auto entries and reversals are paused.',
      );
      return;
    }

    final confidence = plan?.confidence;
    if (reason == 'strategy' &&
        confidence != null &&
        (!confidence.isFinite || confidence < 0.60)) {
      _logExecutionBlocked(
        '${strategy.name} confidence is ${(confidence.isFinite ? confidence * 100 : 0).toStringAsFixed(0)}%, below the 60% auto-execution floor. The plan remains visible for review.',
      );
      return;
    }

    if (_isExchangeSyncMode) {
      final blockMessage = await _ensureLiveStrategyRoutingReady();
      if (blockMessage != null) {
        _logExecutionBlocked(blockMessage);
        return;
      }
      if (plan == null || !plan.isActionable) {
        _logExecutionBlocked(
          plan == null
              ? '${strategy.name} is connected to Binance, but no live plan is available yet.'
              : '${strategy.name} is waiting: ${plan.rationale}',
        );
        return;
      }
      await _submitLiveStrategyPlan(desiredSide, plan: plan);
      return;
    }

    if (_klines.isEmpty) {
      print('No price data available for trade execution');
      return;
    }

    final currentPrice = _klines.last.close;
    final quantity =
        plan?.quantity ??
        riskSettings.resolveQuantity(currentPrice) ??
        riskSettings.tradeQuantity;

    if (!quantity.isFinite || quantity <= 0) {
      print('Trade quantity must be greater than zero');
      return;
    }

    if (_openPosition == null) {
      _openPosition = Position(
        symbol: symbol,
        side: desiredSide,
        entryPrice: currentPrice,
        quantity: quantity,
        entryTime: DateTime.now(),
      );
      _applyPlanRiskTargets(plan, _openPosition);
      _positionController.add(_openPosition);
      _recordEntryTrade(
        desiredSide,
        currentPrice,
        quantity,
        reason,
        orderType: plan?.orderType,
        requestedPrice: plan?.targetEntryPrice,
      );
      return;
    }

    if (_openPosition!.side == desiredSide) {
      _applyPlanRiskTargets(plan, _openPosition);
      return;
    }

    final closeReason = reason == 'strategy' ? 'reversal' : reason;
    _closePosition(
      currentPrice,
      closeReason,
      orderType: plan?.orderType,
      requestedPrice: plan?.targetEntryPrice,
    );
    _openPosition = Position(
      symbol: symbol,
      side: desiredSide,
      entryPrice: currentPrice,
      quantity: quantity,
      entryTime: DateTime.now(),
    );
    _applyPlanRiskTargets(plan, _openPosition);
    _positionController.add(_openPosition);
    _recordEntryTrade(
      desiredSide,
      currentPrice,
      quantity,
      reason,
      orderType: plan?.orderType,
      requestedPrice: plan?.targetEntryPrice,
    );
  }

  Future<String?> _ensureLiveStrategyRoutingReady() async {
    if (!_isExchangeSyncMode) {
      return null;
    }

    if (_binanceAccountStatus.state != BinanceAccountState.active) {
      await _syncExchangeState(logSuccess: true);
    }

    if (_binanceAccountStatus.state == BinanceAccountState.active) {
      if (_futuresPositionMode == BinanceFuturesPositionMode.hedge) {
        return 'Auto execution is blocked in Hedge Mode because this app currently manages one position per symbol. Switch Binance Futures to One-way Mode after closing all positions and orders.';
      }
      if (_futuresPositionMode != BinanceFuturesPositionMode.oneWay) {
        return 'Auto execution is blocked until Binance confirms One-way Position Mode. Refresh the account connection before arming the bot.';
      }
      if (!apiService.allowOrderMutations) {
        return 'Live auto execution is blocked in this environment. Use the desktop app or Binance demo mode.';
      }
      return null;
    }

    return switch (_binanceAccountStatus.state) {
      BinanceAccountState.notConfigured =>
        'Binance API credentials are not configured for auto trading.',
      BinanceAccountState.checking =>
        'Binance is still checking the account connection. Auto execution is waiting.',
      BinanceAccountState.limited =>
        _binanceAccountStatus.message ??
            'Binance is connected in read-only mode. Auto trading needs Futures permissions.',
      BinanceAccountState.attentionRequired =>
        _binanceAccountStatus.message ??
            'Binance connection needs attention before AI or ALGO can place orders.',
      BinanceAccountState.active => null,
    };
  }

  Future<void> _submitLiveStrategyPlan(
    PositionSide desiredSide, {
    required StrategyTradePlan plan,
  }) async {
    if (!_beginOrderSubmission(mayOpenExposure: true)) {
      _logExecutionBlocked(
        'Auto execution is waiting for the previous order submission to finish.',
      );
      return;
    }
    try {
      await _submitLiveStrategyPlanUnlocked(desiredSide, plan: plan);
    } finally {
      _finishOrderSubmission();
    }
  }

  Future<void> _submitLiveStrategyPlanUnlocked(
    PositionSide desiredSide, {
    required StrategyTradePlan plan,
  }) async {
    final executionGeneration = _executionGeneration;
    final quantity = await _resolveLiveStrategyQuantity(plan);
    if (quantity <= 0) {
      _logExecutionBlocked(
        '${strategy.name} generated a ${plan.orderTypeLabel} ${plan.actionLabel} plan, but quantity is 0.',
      );
      return;
    }
    final ambiguityMessage = await _ambiguousEntryBlockMessage();
    if (ambiguityMessage != null) {
      _logExecutionBlocked(ambiguityMessage);
      return;
    }
    if (_hasOwnedEntryIntent &&
        _openPosition == null &&
        _ownedEntryOrders.isEmpty) {
      _logExecutionBlocked(
        'Auto execution is waiting for the previous iFutures entry to finish account reconciliation.',
      );
      return;
    }
    final riskError = _validateEntryRisk(
      quantity: quantity,
      entryPrice: plan.targetEntryPrice ?? plan.currentPrice,
      fallbackStopLossPercent: plan.stopLossPercent,
      leverageOverride: plan.leverage,
    );
    if (riskError != null) {
      _logExecutionBlocked(riskError);
      return;
    }

    final fingerprint = _buildLiveStrategyFingerprint(
      desiredSide,
      plan,
      quantity,
    );
    if (_lastLiveStrategyFingerprint == fingerprint) {
      return;
    }

    if (_ownedEntryOrders.isNotEmpty) {
      _lastLiveStrategyFingerprint = fingerprint;
      _logExecutionBlocked(
        '${strategy.name} did not add another entry because an iFutures order is already working for $symbol.',
      );
      return;
    }

    if (_openPosition != null && _openPosition!.side == desiredSide) {
      _lastLiveStrategyFingerprint = fingerprint;
      _logConsole(
        '${strategy.name} kept the current ${desiredSide == PositionSide.long ? 'LONG' : 'SHORT'} open. Execution style remains ${plan.orderTypeLabel}.',
      );
      return;
    }

    if (!_isAutoExecutionCurrent(executionGeneration)) {
      return;
    }

    _lastLiveStrategyFingerprint = fingerprint;
    try {
      if (_openPosition != null && _openPosition!.side != desiredSide) {
        if (!_ownsActivePosition) {
          _logExecutionBlocked(
            '${strategy.name} will not reverse or close the existing Binance position because it is not owned by this iFutures installation.',
          );
          return;
        }
        if (!_isAutoExecutionCurrent(executionGeneration)) {
          return;
        }
        final closeAction = _openPosition!.isLong
            ? ManualOrderAction.closeLong
            : ManualOrderAction.closeShort;
        await _submitExchangeOrder(
          closeAction,
          quantity: _openPosition!.quantity,
          orderType: ManualOrderType.market,
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _syncExchangeState(logSuccess: true);
        _logConsole(
          '${strategy.name} flattened the opposite position. A fresh signal is required before opening a reversal.',
          level: StrategyConsoleLevel.warning,
        );
        return;
      }

      final submitted = desiredSide == PositionSide.long
          ? await _submitExchangePlanOrder(
              ManualOrderAction.openLong,
              quantity: quantity,
              plan: plan,
              executionGeneration: executionGeneration,
            )
          : await _submitExchangePlanOrder(
              ManualOrderAction.openShort,
              quantity: quantity,
              plan: plan,
              executionGeneration: executionGeneration,
            );
      if (!submitted || !_isAutoExecutionCurrent(executionGeneration)) {
        await _syncExchangeState();
        await cancelBotEntryOrders(reason: 'auto execution was stopped');
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _syncExchangeState(logSuccess: true);
      _syncLiveRiskTargets(plan: plan, replaceExisting: true);
      if (!await _ensureLiveStopProtectionOrFlatten()) {
        _logExecutionBlocked(
          '${strategy.name} entry was flattened because stop protection could not be confirmed.',
        );
        return;
      }
      _logConsole(
        '${strategy.name} sent ${plan.orderTypeLabel.toLowerCase()} ${plan.actionLabel.toLowerCase()} to Binance for ${_formatQuantity(quantity)} ${symbol.toUpperCase()}.',
        level: StrategyConsoleLevel.success,
      );
    } on BinanceRequestOutcomeUnknownException catch (error) {
      await _syncExchangeState();
      final clientId = error.clientOrderId ?? 'unknown';
      _logExecutionBlocked(
        'Binance did not confirm auto order $clientId. No retry will be sent; account reconciliation remains active.',
      );
    } on BinanceApiException catch (error) {
      _lastLiveStrategyFingerprint = null;
      final message =
          error.errorMessage ??
          'Binance rejected the ${plan.orderTypeLabel.toLowerCase()} ${plan.actionLabel.toLowerCase()} request.';
      _logExecutionBlocked(message);
    } catch (error) {
      _lastLiveStrategyFingerprint = null;
      _logExecutionBlocked('Auto execution failed: $error');
    }
  }

  bool _isAutoExecutionCurrent(int generation) =>
      _isAutoTradingEnabled && generation == _executionGeneration;

  Future<double> _resolveLiveStrategyQuantity(StrategyTradePlan plan) async {
    final requestedQuantity =
        plan.quantity ??
        riskSettings.resolveQuantity(
          plan.targetEntryPrice ?? plan.currentPrice,
        ) ??
        riskSettings.tradeQuantity;
    if (!requestedQuantity.isFinite || requestedQuantity <= 0) {
      return requestedQuantity;
    }

    final entryPrice = plan.targetEntryPrice ?? plan.currentPrice;
    if (!entryPrice.isFinite || entryPrice <= 0) {
      return requestedQuantity;
    }

    final rules = await apiService.getSymbolRules(symbol);
    final minimumQuantity = rules?.minimumQuantityForPrice(entryPrice);
    if (minimumQuantity == null || requestedQuantity >= minimumQuantity) {
      return requestedQuantity;
    }

    final requiredNotional = minimumQuantity * entryPrice;
    final leverage = plan.leverage <= 0 ? 1 : plan.leverage;
    final requiredMargin = requiredNotional / leverage;
    if (_availableBalance != null &&
        requiredMargin > (_availableBalance! + 0.0000001)) {
      throw StateError(
        'Configured size is too small for Binance and the minimum tradable order for $symbol needs about ${_formatUsdt(requiredMargin)} margin at ${leverage}x leverage.',
      );
    }

    _logConsole(
      'Raised auto size from ${_formatQuantity(requestedQuantity)} to Binance minimum ${_formatQuantity(minimumQuantity)} ${symbol.toUpperCase()} so the order can actually be accepted.',
      level: StrategyConsoleLevel.warning,
    );
    return minimumQuantity;
  }

  String? _validateEntryRisk({
    required double quantity,
    required double entryPrice,
    double? fallbackStopLossPercent,
    int? leverageOverride,
  }) {
    if (!quantity.isFinite ||
        !entryPrice.isFinite ||
        quantity <= 0 ||
        entryPrice <= 0) {
      return 'Live entry needs a valid quantity and reference price.';
    }
    final stopLossPercent = riskSettings.resolveStopLossPercent(
      entryPrice,
      quantity: quantity,
      fallbackPercent: fallbackStopLossPercent,
    );
    if (!stopLossPercent.isFinite || stopLossPercent <= 0) {
      return 'Live entries require a stop loss. Configure a percentage or estimated USDT max-loss guard first.';
    }
    final leverage = leverageOverride ?? riskSettings.leverage;
    if (leverage < 1 || leverage > 125) {
      return 'Live entry leverage must be between 1x and 125x.';
    }
    final conservativeLimit = 80 / leverage;
    if (stopLossPercent >= conservativeLimit) {
      return 'The configured stop is ${stopLossPercent.toStringAsFixed(2)}% from entry, too close to the estimated liquidation zone at ${leverage}x. Reduce max loss, increase notional, or lower leverage.';
    }
    return null;
  }

  Future<bool> _submitExchangePlanOrder(
    ManualOrderAction action, {
    required double quantity,
    required StrategyTradePlan plan,
    required int executionGeneration,
  }) async {
    if (!_isAutoExecutionCurrent(executionGeneration)) {
      return false;
    }
    final orderType = plan.orderType ?? ManualOrderType.market;
    final entryPrice = plan.targetEntryPrice ?? plan.currentPrice;
    if (action.isOpenAction) {
      await apiService.setLeverage(symbol: symbol, leverage: plan.leverage);
      if (!_isAutoExecutionCurrent(executionGeneration)) {
        return false;
      }
    }

    switch (orderType) {
      case ManualOrderType.market:
        await _submitExchangeOrder(
          action,
          quantity: quantity,
          orderType: orderType,
        );
        return true;
      case ManualOrderType.limit:
      case ManualOrderType.postOnly:
        await _submitExchangeOrder(
          action,
          quantity: quantity,
          orderType: orderType,
          price: entryPrice,
        );
        return true;
      case ManualOrderType.scaled:
        final prices = _buildScaleTargets(
          _scaledPlanStartPrice(action, entryPrice),
          _scaledPlanEndPrice(action, plan, entryPrice),
          3,
        );
        final childQuantity = quantity / prices.length;
        for (final targetPrice in prices) {
          if (!_isAutoExecutionCurrent(executionGeneration)) {
            return false;
          }
          await _submitExchangeOrder(
            action,
            quantity: childQuantity,
            orderType: ManualOrderType.scaled,
            price: targetPrice,
          );
        }
        return true;
    }
  }

  String _buildLiveStrategyFingerprint(
    PositionSide desiredSide,
    StrategyTradePlan plan,
    double quantity,
  ) {
    final target = plan.targetEntryPrice ?? plan.currentPrice;
    final currentSide = _openPosition == null
        ? 'flat'
        : (_openPosition!.isLong ? 'long' : 'short');
    return [
      symbol.toUpperCase(),
      currentSide,
      desiredSide.name,
      plan.orderTypeLabel,
      _formatExchangeDecimal(target),
      _formatExchangeDecimal(quantity),
    ].join('|');
  }

  double _scaledPlanStartPrice(
    ManualOrderAction action,
    double referencePrice,
  ) {
    const spanPercent = 0.0015;
    return switch (action) {
      ManualOrderAction.openLong ||
      ManualOrderAction.closeShort => referencePrice * (1 - spanPercent),
      ManualOrderAction.openShort ||
      ManualOrderAction.closeLong => referencePrice * (1 + spanPercent),
    };
  }

  double _scaledPlanEndPrice(
    ManualOrderAction action,
    StrategyTradePlan plan,
    double referencePrice,
  ) {
    final spreadFactor = ((plan.spreadPercent ?? 0.05) / 100).clamp(
      0.001,
      0.004,
    );
    return switch (action) {
      ManualOrderAction.openLong ||
      ManualOrderAction.closeShort => referencePrice * (1 + spreadFactor),
      ManualOrderAction.openShort ||
      ManualOrderAction.closeLong => referencePrice * (1 - spreadFactor),
    };
  }

  void _recordEntryTrade(
    PositionSide side,
    double price,
    double quantity,
    String reason, {
    ManualOrderType? orderType,
    double? requestedPrice,
  }) {
    final strategyLabel = reason == 'manual' ? 'Manual Ticket' : strategy.name;
    final trade = Trade(
      symbol: symbol,
      side: side == PositionSide.long ? 'BUY' : 'SELL',
      price: price,
      quantity: quantity,
      timestamp: DateTime.now(),
      status: 'simulated',
      strategy: strategyLabel,
      kind: 'ENTRY',
      orderType: orderType?.label,
      requestedPrice: requestedPrice,
      reason: reason,
    );

    _trades.add(trade);
    _tradeController.add(_trades);
    tradeHistoryService.saveTrades(symbol, _trades);
    print(
      'Recorded ENTRY ${trade.side}: ${trade.symbol} @ ${trade.price} (${trade.strategy})',
    );
  }

  void _closePosition(
    double price,
    String reason, {
    ManualOrderType? orderType,
    double? requestedPrice,
  }) {
    final position = _openPosition;
    if (position == null) return;

    _closePositionQuantity(
      expectedSide: position.side,
      price: price,
      quantity: position.quantity,
      reason: reason,
      orderType: orderType,
      requestedPrice: requestedPrice,
    );
  }

  void _closePositionQuantity({
    required PositionSide expectedSide,
    required double price,
    required double quantity,
    required String reason,
    ManualOrderType? orderType,
    double? requestedPrice,
  }) {
    final position = _openPosition;
    if (position == null || position.side != expectedSide) return;

    final closeQuantity = quantity > position.quantity
        ? position.quantity
        : quantity;
    if (closeQuantity <= 0) return;

    final exitSide = position.isLong ? 'SELL' : 'BUY';
    final pnl = position.isLong
        ? (price - position.entryPrice) * closeQuantity
        : (position.entryPrice - price) * closeQuantity;

    final strategyLabel = reason == 'manual' ? 'Manual Ticket' : strategy.name;
    final trade = Trade(
      symbol: symbol,
      side: exitSide,
      price: price,
      quantity: closeQuantity,
      timestamp: DateTime.now(),
      status: 'simulated',
      strategy: strategyLabel,
      kind: 'EXIT',
      realizedPnl: pnl,
      orderType: orderType?.label,
      requestedPrice: requestedPrice,
      reason: reason,
    );

    _trades.add(trade);
    _tradeController.add(_trades);
    tradeHistoryService.saveTrades(symbol, _trades);
    _applyExitProtections(trade);
    final remainingQuantity = position.quantity - closeQuantity;
    _openPosition = remainingQuantity <= 0
        ? null
        : Position(
            symbol: position.symbol,
            side: position.side,
            entryPrice: position.entryPrice,
            quantity: remainingQuantity,
            entryTime: position.entryTime,
            liquidationPrice: position.liquidationPrice,
          );
    if (_openPosition == null) {
      _clearPlanRiskTargets();
    }
    _positionController.add(_openPosition);

    print(
      'Recorded EXIT $exitSide: ${trade.symbol} @ ${trade.price} PnL=$pnl (${trade.reason})',
    );
  }

  void _checkRisk(double currentPrice) {
    final position = _openPosition;
    if (position == null) return;
    if (_isExchangeSyncMode && !_ownsActivePosition) {
      return;
    }
    final uncertainUntil = _riskExitUncertainUntil;
    if (uncertainUntil != null && DateTime.now().isBefore(uncertainUntil)) {
      return;
    }

    final stopLoss =
        _activeStopLossPrice ??
        (riskSettings.hasStopLoss
            ? position.stopLossPrice(
                riskSettings.resolveStopLossPercent(
                  position.entryPrice,
                  quantity: position.quantity,
                ),
              )
            : null);
    if (stopLoss != null) {
      if (position.isLong && currentPrice <= stopLoss) {
        _triggerRiskExit(currentPrice, 'stop_loss');
        return;
      }
      if (!position.isLong && currentPrice >= stopLoss) {
        _triggerRiskExit(currentPrice, 'stop_loss');
        return;
      }
    }

    final takeProfit =
        _activeTakeProfitPrice ??
        (riskSettings.hasTakeProfit
            ? position.takeProfitPrice(
                riskSettings.resolveTakeProfitPercent(
                  position.entryPrice,
                  quantity: position.quantity,
                ),
              )
            : null);
    if (takeProfit != null) {
      if (position.isLong && currentPrice >= takeProfit) {
        _triggerRiskExit(currentPrice, 'take_profit');
        return;
      }
      if (!position.isLong && currentPrice <= takeProfit) {
        _triggerRiskExit(currentPrice, 'take_profit');
        return;
      }
    }
  }

  void _triggerRiskExit(double currentPrice, String reason) {
    if (_isExchangeSyncMode) {
      unawaited(_closeLivePositionForRisk(currentPrice, reason));
      return;
    }
    _closePosition(currentPrice, reason);
  }

  Future<void> _closeLivePositionForRisk(
    double currentPrice,
    String reason,
  ) async {
    if (_isRiskExitInFlight || !_beginOrderSubmission(mayOpenExposure: false)) {
      return;
    }
    _isRiskExitInFlight = true;
    final position = _openPosition;
    if (position == null) {
      _isRiskExitInFlight = false;
      _finishOrderSubmission();
      return;
    }

    final blockMessage = await _ensureLiveStrategyRoutingReady();
    if (blockMessage != null) {
      _logExecutionBlocked('Risk exit blocked: $blockMessage');
      _isRiskExitInFlight = false;
      _finishOrderSubmission();
      return;
    }

    try {
      final closeAction = position.isLong
          ? ManualOrderAction.closeLong
          : ManualOrderAction.closeShort;
      await _submitExchangeOrder(
        closeAction,
        quantity: position.quantity,
        orderType: ManualOrderType.market,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _syncExchangeState(logSuccess: true);
      _clearPlanRiskTargets();
      _logConsole(
        'Sent live ${reason.replaceAll('_', ' ')} close to Binance for ${_formatQuantity(position.quantity)} ${symbol.toUpperCase()}.',
        level: StrategyConsoleLevel.warning,
      );
    } on BinanceRequestOutcomeUnknownException catch (error) {
      _riskExitUncertainUntil = DateTime.now().add(const Duration(seconds: 10));
      await _syncExchangeState();
      _logExecutionBlocked(
        'Risk-exit order ${error.clientOrderId ?? 'unknown'} has an unconfirmed Binance outcome. No duplicate close will be sent for 10 seconds while reconciliation continues.',
      );
    } catch (error) {
      _logExecutionBlocked('Risk exit failed: $error');
    } finally {
      _isRiskExitInFlight = false;
      _finishOrderSubmission();
    }
  }

  void stopMarketData() {
    _isStreaming = false;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _stopUserDataStream();
    _logConsole('Market stream stopped.', level: StrategyConsoleLevel.warning);
    _stopExchangeSyncTimer();
    _stopConnectionTicker();
    _emitConnectionStatus(forceDisconnected: true);
  }

  void stop() {
    disableTrading();
    stopMarketData();
  }

  void dispose() {
    disableTrading(reason: 'engine_disposed');
    stopMarketData();
    _klineController.close();
    _tradeController.close();
    _accountTradeController.close();
    _positionController.close();
    _protectionController.close();
    _connectionController.close();
    _binanceAccountController.close();
    _signalController.close();
    _decisionPlanController.close();
    _consoleLogController.close();
    _pendingOrderController.close();
    _openOrderController.close();
    _orderBookSnapshotController.close();
  }

  void _recordMessageTimestamp(Map<String, dynamic> event) {
    _lastMessageAt = DateTime.now();
    final eventTime =
        event['E'] ?? (event['k'] is Map ? event['k']['T'] : null);
    if (eventTime is int) {
      _lastLatencyMs = (_lastMessageAt!.millisecondsSinceEpoch - eventTime)
          .abs();
    } else if (eventTime is String) {
      final parsed = int.tryParse(eventTime);
      if (parsed != null) {
        _lastLatencyMs = (_lastMessageAt!.millisecondsSinceEpoch - parsed)
            .abs();
      }
    }
    _emitConnectionStatus();
  }

  void _startConnectionTicker() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitConnectionStatus();
    });
  }

  void _stopConnectionTicker() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

  void _emitConnectionStatus({bool forceDisconnected = false}) {
    if (_connectionController.isClosed) return;

    if (forceDisconnected || !_isStreaming) {
      _connectionController.add(
        ConnectionStatus.disconnected(lastMessageAt: _lastMessageAt),
      );
      return;
    }

    if (_lastMessageAt == null) {
      _connectionController.add(ConnectionStatus.connecting());
      return;
    }

    final ageSeconds = DateTime.now().difference(_lastMessageAt!).inSeconds;
    final state = ageSeconds <= 3
        ? MarketConnectionState.connected
        : ageSeconds <= 15
        ? MarketConnectionState.stale
        : MarketConnectionState.disconnected;

    _connectionController.add(
      ConnectionStatus(
        state: state,
        latencyMs: _lastLatencyMs,
        lastMessageAt: _lastMessageAt,
      ),
    );
  }

  void _handleConnectionStatusUpdate(ConnectionStatus status) {
    if (_connectionController.isClosed) return;

    _connectionController.add(
      status.copyWith(
        lastMessageAt: status.lastMessageAt ?? _lastMessageAt,
        latencyMs: status.latencyMs ?? _lastLatencyMs,
      ),
    );
  }

  Future<void> clearTrades() async {
    _trades = [];
    _tradeController.add(_trades);
    _clearPlanRiskTargets();
    _cooldownUntil = null;
    _protectionLockUntil = null;
    _protectionLockReason = null;
    _emitProtectionStatus(
      const ProtectionStatus.ready(
        message: 'Protection engine is clear. Auto entries are allowed.',
      ),
    );
    await tradeHistoryService.clearTrades(symbol);
  }

  Future<OrderBookSnapshot?> refreshOrderBook() async {
    await _refreshOrderBookContextIfNeeded(force: true);
    return _orderBookSnapshot;
  }

  Future<int> cancelBotEntryOrders({
    String reason = 'execution disarmed',
  }) async {
    if (!_isExchangeSyncMode || !apiService.allowOrderMutations) {
      return 0;
    }

    await _reconcileAmbiguousEntryIntents();
    final orderIdsByClientId = <String, String>{
      for (final order in _ownedEntryOrders)
        if (order.orderId.isNotEmpty)
          (order.clientOrderId ?? order.orderId): order.orderId,
      for (final intent in _ambiguousEntryIntents.values)
        if (intent.orderId != null && intent.orderId!.isNotEmpty)
          intent.clientOrderId: intent.orderId!,
    };
    final unresolvedClientIds = _ambiguousEntryIntents.values
        .where((intent) => intent.orderId == null || intent.orderId!.isEmpty)
        .map((intent) => intent.clientOrderId)
        .toList();
    if (orderIdsByClientId.isEmpty && unresolvedClientIds.isEmpty) {
      return 0;
    }

    final cancelledIds = <String>{};
    final failures = <String>[];
    for (final entry in orderIdsByClientId.entries) {
      try {
        await apiService.cancelOrder(symbol: symbol, orderId: entry.value);
        cancelledIds.add(entry.value);
      } catch (error) {
        failures.add('${entry.value}: $error');
      }
    }
    failures.addAll(
      unresolvedClientIds.map(
        (clientId) => '$clientId: Binance has not exposed an order id yet',
      ),
    );

    if (cancelledIds.isNotEmpty) {
      _openOrders = _openOrders
          .where((order) => !cancelledIds.contains(order.orderId))
          .toList();
      if (_openPosition == null && _ownedEntryOrders.isEmpty) {
        _hasOwnedEntryIntent = false;
      }
      _emitOpenOrders();
      _logConsole(
        'Cancelled ${cancelledIds.length} iFutures entry order${cancelledIds.length == 1 ? '' : 's'} because ${reason.replaceAll('_', ' ')}.',
        level: StrategyConsoleLevel.warning,
      );
    }

    if (failures.isNotEmpty) {
      throw StateError(
        'Entry cancellation was not fully confirmed: ${failures.join('; ')}',
      );
    }
    return cancelledIds.length;
  }

  Future<bool> _loadInitialAccountState() async {
    if (!apiService.hasCredentials) {
      return false;
    }

    return _syncExchangeState(logSuccess: true);
  }

  Future<void> _refreshFuturesPositionMode({bool logChange = false}) async {
    if (!apiService.hasCredentials) {
      return;
    }

    final previousMode = _futuresPositionMode;
    try {
      final resolvedMode = await apiService.getPositionMode();
      _futuresPositionMode = resolvedMode;
      if (logChange || resolvedMode != previousMode) {
        _logConsole(
          'Binance futures mode detected: ${_futuresPositionModeLabel}.',
        );
      }
    } catch (error) {
      if (logChange) {
        _logConsole(
          'Could not confirm Binance futures mode. Using ${_futuresPositionModeLabel} assumptions for now.',
          level: StrategyConsoleLevel.warning,
        );
      }
    }
  }

  void _startExchangeSyncTimer() {
    _exchangeSyncTimer?.cancel();
    _exchangeSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(_refreshOrderBookContextIfNeeded());
      if (apiService.hasCredentials) {
        unawaited(_syncExchangeState());
      }
    });
  }

  void _stopExchangeSyncTimer() {
    _exchangeSyncTimer?.cancel();
    _exchangeSyncTimer = null;
  }

  Future<void> _startUserDataStream({bool fromRetry = false}) async {
    if (!apiService.hasCredentials ||
        !_isStreaming ||
        _userDataSubscription != null ||
        _isStartingUserDataStream ||
        (!fromRetry && _userDataRetryTimer != null)) {
      return;
    }

    _isStartingUserDataStream = true;
    try {
      final listenKey = await apiService.startUserDataStream();
      if (!_isStreaming) {
        unawaited(apiService.closeUserDataStream(listenKey));
        return;
      }
      _userDataListenKey = listenKey;
      _userDataSubscription = wsService
          .subscribeToUserData(listenKey)
          .listen(
            _handleUserDataEvent,
            onError: (Object error) {
              _handleUserDataStreamDisconnect(error: error);
            },
            onDone: _handleUserDataStreamDisconnect,
            cancelOnError: true,
          );
      _userDataKeepAliveTimer?.cancel();
      _userDataRetryTimer?.cancel();
      _userDataRetryTimer = null;
      _userDataRetryAttempt = 0;
      _userDataKeepAliveTimer = Timer.periodic(
        const Duration(minutes: 25),
        (_) => unawaited(_keepUserDataStreamAlive()),
      );
      _logConsole(
        'Binance fill and order-event stream is active for immediate protection checks.',
        level: StrategyConsoleLevel.success,
      );
    } catch (error) {
      _logConsole(
        'Binance user-data stream could not start: $error. Periodic account sync remains active while the stream retries.',
        level: StrategyConsoleLevel.warning,
      );
      _scheduleUserDataStreamRetry();
    } finally {
      _isStartingUserDataStream = false;
    }
  }

  void _scheduleUserDataStreamRetry() {
    if (!_isStreaming ||
        !apiService.hasCredentials ||
        _userDataSubscription != null ||
        _userDataRetryTimer != null) {
      return;
    }

    final baseMs = userDataRetryBaseDelay.inMilliseconds < 1
        ? 1
        : userDataRetryBaseDelay.inMilliseconds;
    final maxMs = userDataRetryMaxDelay.inMilliseconds < baseMs
        ? baseMs
        : userDataRetryMaxDelay.inMilliseconds;
    var delayMs = baseMs;
    for (
      var index = 0;
      index < _userDataRetryAttempt && delayMs < maxMs;
      index++
    ) {
      delayMs = (delayMs * 2).clamp(1, maxMs).toInt();
    }
    _userDataRetryAttempt += 1;
    final delay = Duration(milliseconds: delayMs);
    _userDataRetryTimer = Timer(delay, () {
      _userDataRetryTimer = null;
      if (_isStreaming && _userDataSubscription == null) {
        unawaited(_startUserDataStream(fromRetry: true));
      }
    });
    _logConsole(
      'Retrying the Binance user-data stream in ${delay.inSeconds > 0 ? '${delay.inSeconds}s' : '${delay.inMilliseconds}ms'}.',
      level: StrategyConsoleLevel.warning,
    );
  }

  void _handleUserDataStreamDisconnect({Object? error}) {
    final subscription = _userDataSubscription;
    if (subscription == null) {
      return;
    }
    _userDataSubscription = null;
    unawaited(subscription.cancel());
    _userDataKeepAliveTimer?.cancel();
    _userDataKeepAliveTimer = null;
    final listenKey = _userDataListenKey;
    _userDataListenKey = null;
    if (listenKey != null && apiService.hasCredentials) {
      unawaited(apiService.closeUserDataStream(listenKey).catchError((_) {}));
    }
    _logConsole(
      error == null
          ? 'Binance user-data stream closed. Periodic account sync remains active while the stream reconnects.'
          : 'Binance user-data stream error: $error. Periodic account sync remains active while the stream reconnects.',
      level: StrategyConsoleLevel.warning,
    );
    _scheduleUserDataStreamRetry();
  }

  Future<void> _keepUserDataStreamAlive() async {
    final listenKey = _userDataListenKey;
    if (listenKey == null || !_isStreaming) {
      return;
    }
    try {
      await apiService.keepAliveUserDataStream(listenKey);
    } catch (error) {
      _logConsole(
        'Binance user-data keepalive failed; renewing the stream: $error',
        level: StrategyConsoleLevel.warning,
      );
      await _restartUserDataStream();
    }
  }

  void _handleUserDataEvent(dynamic payload) {
    if (payload is! Map) {
      return;
    }
    final eventType = '${payload['e'] ?? payload['eventType'] ?? ''}'
        .toUpperCase();
    if (eventType == 'LISTENKEYEXPIRED' || eventType == 'LISTEN_KEY_EXPIRED') {
      unawaited(_restartUserDataStream());
      return;
    }
    if (eventType != 'ORDER_TRADE_UPDATE' &&
        eventType != 'ACCOUNT_UPDATE' &&
        eventType != 'ALGO_UPDATE') {
      return;
    }

    _userDataSyncDebounceTimer?.cancel();
    _userDataSyncDebounceTimer = Timer(const Duration(milliseconds: 120), () {
      if (_isStreaming) {
        unawaited(_syncExchangeState());
      }
    });
  }

  Future<void> _restartUserDataStream() async {
    _stopUserDataStream(closeRemote: false);
    if (_isStreaming) {
      await _startUserDataStream();
    }
  }

  void _stopUserDataStream({bool closeRemote = true}) {
    _userDataKeepAliveTimer?.cancel();
    _userDataKeepAliveTimer = null;
    _userDataSyncDebounceTimer?.cancel();
    _userDataSyncDebounceTimer = null;
    _userDataRetryTimer?.cancel();
    _userDataRetryTimer = null;
    _userDataRetryAttempt = 0;
    final subscription = _userDataSubscription;
    _userDataSubscription = null;
    unawaited(subscription?.cancel());
    final listenKey = _userDataListenKey;
    _userDataListenKey = null;
    if (closeRemote && listenKey != null && apiService.hasCredentials) {
      unawaited(apiService.closeUserDataStream(listenKey).catchError((_) {}));
    }
  }

  Future<void> _refreshOrderBookContextIfNeeded({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _orderBookSyncedAt != null &&
        now.difference(_orderBookSyncedAt!) < const Duration(minutes: 1)) {
      return;
    }

    try {
      final payload = await apiService.getOrderBook(symbol: symbol, limit: 20);
      final plannedQuantity =
          riskSettings.resolveQuantity(
            _klines.isNotEmpty ? _klines.last.close : null,
          ) ??
          riskSettings.tradeQuantity;
      final snapshot = OrderBookAnalyzer.analyze(
        payload,
        plannedQuantity: plannedQuantity,
        capturedAt: now,
      );
      final previousCapturedAt = _orderBookSyncedAt;
      _orderBookSnapshot = snapshot;
      _orderBookHistory = [..._orderBookHistory, snapshot];
      if (_orderBookHistory.length > 8) {
        _orderBookHistory = _orderBookHistory.sublist(
          _orderBookHistory.length - 8,
        );
      }
      _orderBookSyncedAt = now;
      _emitOrderBookSnapshot(snapshot);
      final trendSnapshot = orderBookTrendSnapshot;

      if (previousCapturedAt == null ||
          now.difference(previousCapturedAt) >= const Duration(minutes: 1)) {
        _logConsole(
          'Order book updated: spread ${snapshot.spreadPercent?.toStringAsFixed(4) ?? '--'}%, '
          'imbalance ${snapshot.imbalancePercent.toStringAsFixed(1)}%, '
          'buy slip ${snapshot.estimatedBuySlippagePercent?.toStringAsFixed(4) ?? '--'}%, '
          'sell slip ${snapshot.estimatedSellSlippagePercent?.toStringAsFixed(4) ?? '--'}%. '
          '${snapshot.executionHint}. '
          '${trendSnapshot?.trendLabel ?? 'Book trend unavailable.'}',
        );
      }
    } catch (e) {
      if (_orderBookSnapshot == null) {
        _logConsole(
          'Order book snapshot unavailable: $e',
          level: StrategyConsoleLevel.warning,
        );
      }
    }
  }

  Future<bool> _syncExchangeState({bool logSuccess = false}) async {
    if (_isExchangeSyncInFlight) {
      await _exchangeSyncCompleter?.future;
      return _syncExchangeState(logSuccess: logSuccess);
    }
    _isExchangeSyncInFlight = true;
    _exchangeSyncCompleter = Completer<void>();
    if (!apiService.hasCredentials) {
      _emitBinanceAccountStatus(
        BinanceAccountStatus.notConfigured(
          isTestnet: apiService.isTestnet,
          message: 'Binance API credentials are not configured.',
        ),
      );
      _isExchangeSyncInFlight = false;
      _exchangeSyncCompleter?.complete();
      _exchangeSyncCompleter = null;
      return false;
    }

    try {
      await _refreshFuturesPositionMode(logChange: logSuccess);
      final results = await Future.wait<dynamic>([
        apiService.getPositionRisk(symbol: symbol),
        apiService.getAccountInfo(),
        apiService.getOpenOrders(symbol: symbol),
        apiService.getOpenAlgoOrders(symbol: symbol),
        ...trackedSymbols.map(
          (trackedSymbol) =>
              apiService.getUserTrades(symbol: trackedSymbol, limit: 100),
        ),
      ]);

      final syncedPosition = _parseExchangePosition(
        results.first as List<dynamic>,
      );
      final accountSummary = _parseExchangeAccountSummary(
        results[1] as Map<String, dynamic>,
      );
      final syncedOpenOrders = <LiveOrder>[
        ..._parseExchangeOpenOrders(results[2] as List<dynamic>),
        ..._parseExchangeOpenAlgoOrders(results[3] as List<dynamic>),
      ]..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      final groupedTrades = <String, List<Trade>>{};
      for (var i = 0; i < trackedSymbols.length; i++) {
        final trackedSymbol = trackedSymbols[i];
        groupedTrades[trackedSymbol] = _parseExchangeTrades(
          results[i + 4] as List<dynamic>,
          symbolFilter: trackedSymbol,
        );
      }
      final normalizedSymbol = symbol.toUpperCase();
      final syncedTrades = groupedTrades[normalizedSymbol] ?? const <Trade>[];
      final syncedAccountTrades =
          groupedTrades.values.expand((trades) => trades).toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final positionChanged = !_samePosition(_openPosition, syncedPosition);
      final tradesChanged = !_sameTrades(_trades, syncedTrades);
      final accountTradesChanged = !_sameTrades(
        _accountTrades,
        syncedAccountTrades,
      );
      final openOrdersChanged = !_sameOpenOrders(_openOrders, syncedOpenOrders);

      final hasOwnedEntryOrder = syncedOpenOrders.any(
        (order) => order.isEntryOrderOwnedBy(clientOrderOwnerId),
      );
      _openPosition = syncedPosition;
      if (_openPosition == null) {
        _ownsActivePosition = false;
        _hasOwnedEntryIntent =
            hasOwnedEntryOrder || _ambiguousEntryIntents.isNotEmpty;
        _clearPlanRiskTargets();
      } else {
        if (positionChanged) {
          _ownsActivePosition = _hasOwnedEntryIntent;
        } else if (_hasOwnedEntryIntent) {
          _ownsActivePosition = true;
        }
        if (positionChanged ||
            (_activeTakeProfitPrice == null && _activeStopLossPrice == null)) {
          _syncLiveRiskTargets(plan: _lastDecisionPlan, replaceExisting: true);
        }
      }
      _trades = syncedTrades;
      _accountTrades = syncedAccountTrades;
      _openOrders = syncedOpenOrders;
      await _reconcileAmbiguousEntryIntents(accountSnapshotIsCurrent: true);
      _walletBalance = accountSummary.walletBalance;
      _availableBalance = accountSummary.availableBalance;
      _openPositionCount = accountSummary.openPositionCount;
      _lastExecutionBlockFingerprint = null;
      if (positionChanged || tradesChanged || accountTradesChanged) {
        _lastLiveStrategyFingerprint = null;
      }
      _positionController.add(_openPosition);
      _tradeController.add(_trades);
      _accountTradeController.add(_accountTrades);
      _emitOpenOrders();
      _restoreProtectionWindowsFromTrades();
      await Future.wait([
        for (final entry in groupedTrades.entries)
          tradeHistoryService.saveTrades(entry.key, entry.value),
      ]);

      if (logSuccess ||
          positionChanged ||
          tradesChanged ||
          accountTradesChanged ||
          openOrdersChanged) {
        final positionLabel = _openPosition == null
            ? 'no open position'
            : '${_openPosition!.isLong ? 'LONG' : 'SHORT'} '
                  '${_formatQuantity(_openPosition!.quantity)} @ '
                  '${_openPosition!.entryPrice.toStringAsFixed(_openPosition!.entryPrice >= 100 ? 2 : 6)}';
        _logConsole(
          'Synced Binance account state: ${_trades.length} ${symbol.toUpperCase()} fills, ${_accountTrades.length} tracked fills total, ${_openOrders.length} working orders, $positionLabel. Wallet ${_walletBalance?.toStringAsFixed(2) ?? '--'} USDT, available ${_availableBalance?.toStringAsFixed(2) ?? '--'} USDT. Mode ${_futuresPositionModeLabel}.',
          level: StrategyConsoleLevel.success,
        );
      }
      _emitBinanceAccountStatus(
        BinanceAccountStatus.active(
          isTestnet: apiService.isTestnet,
          lastSyncedAt: DateTime.now(),
          message:
              '${apiService.isTestnet ? 'Binance demo' : 'Binance live'} account sync is active.',
        ),
      );
      unawaited(_startUserDataStream());
      await _reconcileExchangeProtectionOrders(plan: _lastDecisionPlan);
      if (!_isAutoTradingEnabled &&
          !_manualOverrideActive &&
          _ownedEntryOrders.isNotEmpty &&
          apiService.allowOrderMutations) {
        try {
          await cancelBotEntryOrders(reason: 'execution is disarmed');
        } catch (error) {
          _logExecutionBlocked(
            'A disarmed iFutures entry still needs cancellation confirmation: $error',
          );
        }
      }
      return true;
    } catch (e) {
      final limitedMessage = await _buildLimitedExchangeAccessMessage(e);
      if (limitedMessage != null) {
        _emitBinanceAccountStatus(
          BinanceAccountStatus.limited(
            isTestnet: apiService.isTestnet,
            lastSyncedAt: _binanceAccountStatus.lastSyncedAt,
            message: limitedMessage,
          ),
        );
        if (logSuccess) {
          _logConsole(limitedMessage, level: StrategyConsoleLevel.warning);
        }
        return false;
      }

      _emitBinanceAccountStatus(
        BinanceAccountStatus.attentionRequired(
          isTestnet: apiService.isTestnet,
          lastSyncedAt: _binanceAccountStatus.lastSyncedAt,
          message: _friendlyExchangeSyncError(e),
        ),
      );
      if (logSuccess) {
        _logConsole(
          _friendlyExchangeSyncError(e),
          level: StrategyConsoleLevel.warning,
        );
      }
      return false;
    } finally {
      _isExchangeSyncInFlight = false;
      _exchangeSyncCompleter?.complete();
      _exchangeSyncCompleter = null;
    }
  }

  Future<String?> _buildLimitedExchangeAccessMessage(Object error) async {
    if (apiService.isTestnet || error is! BinanceApiException) {
      return null;
    }

    final isPermissionStyleFailure =
        error.errorCode == -2015 ||
        error.errorCode == -2014 ||
        error.body.contains('-2015') ||
        error.body.contains('-2014');
    if (!isPermissionStyleFailure) {
      return null;
    }

    try {
      await apiService.syncServerTime(scope: BinanceApiScope.spot);
      final spotAccountInfo = await apiService.getSpotAccountInfo();
      Map<String, dynamic>? spotRestrictions;
      try {
        spotRestrictions = await apiService.getSpotApiRestrictions();
      } catch (_) {
        // A successful spot account call is enough to prove the key works.
      }

      final balances = spotAccountInfo['balances'];
      final fundedAssetCount = balances is List
          ? balances.where((item) {
              if (item is! Map) return false;
              final free = double.tryParse('${item['free'] ?? 0}') ?? 0;
              final locked = double.tryParse('${item['locked'] ?? 0}') ?? 0;
              return free != 0 || locked != 0;
            }).length
          : 0;

      final futuresEnabled = spotRestrictions?['enableFutures'];
      final futuresFlagNote = futuresEnabled is bool
          ? futuresEnabled
                ? ' Binance reports Futures permission is enabled on the key.'
                : ' Binance reports Futures permission is disabled on the key.'
          : '';

      return 'Spot read access is valid, so the key and secret are at least partially working. '
          '${fundedAssetCount > 0 ? 'Spot returned $fundedAssetCount funded asset${fundedAssetCount == 1 ? '' : 's'}. ' : 'Spot returned no funded assets. '}'
          'The dashboard is blocked specifically on Binance Futures sync for this app.$futuresFlagNote';
    } catch (_) {
      return null;
    }
  }

  String _friendlyExchangeSyncError(Object error) {
    if (error is BinanceApiException) {
      if (error.errorCode == -1022 || error.body.contains('-1022')) {
        return 'Binance account sync failed: invalid API signature. Re-enter the Binance API secret or create a fresh key pair for this app.';
      }
      if (error.errorCode == -1021 || error.body.contains('-1021')) {
        return 'Binance account sync failed because this machine clock is ahead of Binance server time. The app is retrying with server time.';
      }
      if (error.errorCode == -2015 ||
          error.errorCode == -2014 ||
          error.body.contains('-2015') ||
          error.body.contains('-2014')) {
        final requestIp = _extractRequestIp(error.body);
        final requestIpText = requestIp == null
            ? ''
            : ' Binance reported request IP $requestIp.';
        return 'Binance account sync failed: API key, IP whitelist, or Futures permission was rejected by Binance.$requestIpText';
      }
    }

    return 'Binance account sync failed, falling back to local cache: $error';
  }

  bool get _isExchangeSyncMode => apiService.hasCredentials;

  List<LiveOrder> get _currentProtectionOrders => _openOrders
      .where(
        (order) =>
            order.isProtectionOrder && order.isOwnedBy(clientOrderOwnerId),
      )
      .toList();

  List<LiveOrder> get _ownedEntryOrders => _openOrders
      .where((order) => order.isEntryOrderOwnedBy(clientOrderOwnerId))
      .toList();

  Future<void> _reconcileExchangeProtectionOrders({
    StrategyTradePlan? plan,
  }) async {
    if (!_isExchangeSyncMode ||
        _binanceAccountStatus.state != BinanceAccountState.active ||
        _isProtectionOrderSyncInFlight) {
      return;
    }
    if (_futuresPositionMode == BinanceFuturesPositionMode.unknown) {
      _logExecutionBlocked(
        'TP/SL synchronization is paused until Binance confirms the Futures position mode.',
      );
      return;
    }

    _isProtectionOrderSyncInFlight = true;
    try {
      final position = _openPosition;
      final existingProtectionOrders = _currentProtectionOrders;
      if (position == null) {
        if (existingProtectionOrders.isNotEmpty) {
          await _cancelExchangeProtectionOrdersIfNeeded(
            reason: 'no open position remains',
          );
        }
        return;
      }

      if (!_ownsActivePosition) {
        _logExecutionBlocked(
          'An existing Binance position is being monitored but is not owned by this iFutures installation. Its orders will not be changed, even if stale iFutures protection is visible. Manage it on Binance or close it before arming a new bot trade.',
        );
        return;
      }

      _syncLiveRiskTargets(plan: plan, replaceExisting: false);
      final takeProfit = _activeTakeProfitPrice;
      final stopLoss = _activeStopLossPrice;

      if ((takeProfit == null || takeProfit <= 0) &&
          (stopLoss == null || stopLoss <= 0)) {
        if (existingProtectionOrders.isNotEmpty) {
          await _cancelExchangeProtectionOrdersIfNeeded(
            reason: 'TP/SL rules are disabled',
          );
        }
        return;
      }

      final rules = await apiService.getSymbolRules(symbol);
      final normalizedTakeProfit = takeProfit == null
          ? null
          : (rules?.normalizePrice(takeProfit) ?? takeProfit);
      final normalizedStopLoss = stopLoss == null
          ? null
          : (rules?.normalizePrice(stopLoss) ?? stopLoss);
      final closeSide = position.isLong ? 'SELL' : 'BUY';
      final positionSide = _exchangePositionSideForPosition(position);

      final matchingTakeProfit = normalizedTakeProfit == null
          ? null
          : _matchingProtectionOrder(
              existingProtectionOrders,
              type: 'TAKE_PROFIT_MARKET',
              side: closeSide,
              stopPrice: normalizedTakeProfit,
              positionSide: positionSide,
              position: position,
            );
      final matchingStopLoss = normalizedStopLoss == null
          ? null
          : _matchingProtectionOrder(
              existingProtectionOrders,
              type: 'STOP_MARKET',
              side: closeSide,
              stopPrice: normalizedStopLoss,
              positionSide: positionSide,
              position: position,
            );
      final expectedCount =
          (normalizedTakeProfit != null ? 1 : 0) +
          (normalizedStopLoss != null ? 1 : 0);
      final needsRefresh =
          existingProtectionOrders.length != expectedCount ||
          (normalizedTakeProfit != null && matchingTakeProfit == null) ||
          (normalizedStopLoss != null && matchingStopLoss == null);
      if (!needsRefresh) {
        return;
      }

      // Install and record the replacement stop before removing old protection.
      // Binance USD-M Futures has no atomic bracket/OCO transaction, so this
      // ordering avoids an unprotected gap during a refresh.
      final retainedOrders = <LiveOrder>[];
      final createdOrders = <LiveOrder>[];
      if (normalizedStopLoss != null) {
        final stopOrder =
            matchingStopLoss ??
            await _submitExchangeProtectionOrder(
              type: 'STOP_MARKET',
              side: closeSide,
              stopPrice: normalizedStopLoss,
              position: position,
            );
        retainedOrders.add(stopOrder);
        if (matchingStopLoss == null) {
          createdOrders.add(stopOrder);
          _appendOwnedProtectionOrder(stopOrder);
        }
      }
      if (normalizedTakeProfit != null) {
        final takeProfitOrder =
            matchingTakeProfit ??
            await _submitExchangeProtectionOrder(
              type: 'TAKE_PROFIT_MARKET',
              side: closeSide,
              stopPrice: normalizedTakeProfit,
              position: position,
            );
        retainedOrders.add(takeProfitOrder);
        if (matchingTakeProfit == null) {
          createdOrders.add(takeProfitOrder);
          _appendOwnedProtectionOrder(takeProfitOrder);
        }
      }

      await _cancelExchangeProtectionOrdersIfNeeded(
        reason: 'refreshing Binance TP/SL protection',
        preserveOrderIds: retainedOrders.map((order) => order.orderId).toSet(),
      );
      _replaceOwnedProtectionOrders(retainedOrders);

      if (createdOrders.isNotEmpty) {
        _logConsole(
          'Placed Binance TP/SL protection for ${position.isLong ? 'LONG' : 'SHORT'} ${symbol.toUpperCase()}: TP ${normalizedTakeProfit == null ? '--' : _formatPriceValue(normalizedTakeProfit)}, SL ${normalizedStopLoss == null ? '--' : _formatPriceValue(normalizedStopLoss)}.',
          level: StrategyConsoleLevel.success,
        );
      }
    } catch (error) {
      _logExecutionBlocked('TP/SL protection sync failed: $error');
    } finally {
      _isProtectionOrderSyncInFlight = false;
    }
  }

  void _replaceOwnedProtectionOrders(List<LiveOrder> replacements) {
    _openOrders = [
      ..._openOrders.where(
        (order) =>
            !(order.isProtectionOrder && order.isOwnedBy(clientOrderOwnerId)),
      ),
      ...replacements,
    ]..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    _emitOpenOrders();
  }

  void _appendOwnedProtectionOrder(LiveOrder order) {
    _openOrders = [..._openOrders, order]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    _emitOpenOrders();
  }

  Future<bool> _ensureLiveStopProtectionOrFlatten() async {
    final position = _openPosition;
    if (position == null || _activeStopLossPrice == null) {
      return true;
    }

    await _reconcileExchangeProtectionOrders(plan: _lastDecisionPlan);
    BinanceSymbolRules? rules;
    try {
      rules = await apiService.getSymbolRules(symbol);
    } catch (_) {
      // Confirmation still falls through to emergency flatten if rules cannot
      // be refreshed; a read failure must not count as verified protection.
    }
    final normalizedStop =
        rules?.normalizePrice(_activeStopLossPrice!) ?? _activeStopLossPrice!;
    final closeSide = position.isLong ? 'SELL' : 'BUY';
    final positionSide = _exchangePositionSideForPosition(position);
    final localStop = _matchingProtectionOrder(
      _currentProtectionOrders,
      type: 'STOP_MARKET',
      side: closeSide,
      stopPrice: normalizedStop,
      positionSide: positionSide,
      position: position,
    );
    final freshlyReadStop = localStop?.clientOrderId == null
        ? null
        : await _reconcileUnknownAlgoOrder(localStop!.clientOrderId!);
    final confirmedStop = freshlyReadStop == null
        ? null
        : _matchingProtectionOrder(
            <LiveOrder>[freshlyReadStop],
            type: 'STOP_MARKET',
            side: closeSide,
            stopPrice: normalizedStop,
            positionSide: positionSide,
            position: position,
          );
    if (confirmedStop != null) {
      return true;
    }

    _logExecutionBlocked(
      'Critical: Binance stop protection could not be confirmed. Flattening the iFutures-owned position instead of leaving live exposure unprotected.',
    );
    final closeAction = position.isLong
        ? ManualOrderAction.closeLong
        : ManualOrderAction.closeShort;
    try {
      await _submitExchangeOrder(
        closeAction,
        quantity: position.quantity,
        orderType: ManualOrderType.market,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _syncExchangeState(logSuccess: true);
    } catch (error) {
      _logExecutionBlocked(
        'Emergency flatten failed. Close the position on Binance immediately: $error',
      );
    }
    return false;
  }

  Future<void> _cancelExchangeProtectionOrdersIfNeeded({
    required String reason,
    Set<String> preserveOrderIds = const <String>{},
  }) async {
    final protectionOrders = _currentProtectionOrders
        .where((order) => !preserveOrderIds.contains(order.orderId))
        .toList();
    if (protectionOrders.isEmpty) {
      return;
    }

    final cancelledIds = <String>{};
    final failures = <String>[];
    for (final order in protectionOrders) {
      if (order.orderId.isEmpty) {
        failures.add('missing order id (${order.clientOrderId ?? 'unknown'})');
        continue;
      }
      try {
        if (order.isAlgo) {
          await apiService.cancelAlgoOrder(algoId: order.orderId);
        } else {
          await apiService.cancelOrder(symbol: symbol, orderId: order.orderId);
        }
        cancelledIds.add(order.orderId);
      } catch (error) {
        failures.add('${order.orderId}: $error');
        _logExecutionBlocked(
          'Failed to cancel Binance protection order ${order.orderId}: $error',
        );
      }
    }

    _openOrders = _openOrders
        .where((order) => !cancelledIds.contains(order.orderId))
        .toList();
    _emitOpenOrders();
    if (cancelledIds.isNotEmpty) {
      _logConsole(
        'Cancelled ${cancelledIds.length} Binance TP/SL order${cancelledIds.length == 1 ? '' : 's'} because $reason.',
        level: StrategyConsoleLevel.warning,
      );
    }
    if (failures.isNotEmpty) {
      throw StateError(
        'Protection cancellation was not fully confirmed: ${failures.join('; ')}',
      );
    }
  }

  Future<LiveOrder> _submitExchangeProtectionOrder({
    required String type,
    required String side,
    required double stopPrice,
    required Position position,
  }) async {
    final rules = await apiService.getSymbolRules(symbol);
    final formattedStopPrice =
        rules?.formatPrice(stopPrice) ?? _formatExchangeDecimal(stopPrice);
    final positionSide = _exchangePositionSideForPosition(position);
    final clientAlgoId = _nextClientOrderId(
      type == 'STOP_MARKET' ? 'sl' : 'tp',
    );
    late final Map<String, dynamic> response;
    try {
      response = await apiService.placeAlgoOrder(
        symbol: symbol,
        side: side,
        type: type,
        triggerPrice: formattedStopPrice,
        positionSide: positionSide,
        closePosition: true,
        workingType: 'MARK_PRICE',
        priceProtect: false,
        clientAlgoId: clientAlgoId,
      );
    } on BinanceRequestOutcomeUnknownException {
      final reconciled = await _reconcileUnknownAlgoOrder(clientAlgoId);
      if (reconciled == null) {
        rethrow;
      }
      _logConsole(
        'Recovered an uncertain Binance algo response by finding $clientAlgoId. No duplicate protection order was sent.',
        level: StrategyConsoleLevel.warning,
      );
      return reconciled;
    }
    final algoId = response['algoId']?.toString() ?? '';
    if (algoId.isEmpty) {
      throw StateError(
        'Binance accepted no verifiable algo order id for $type protection.',
      );
    }
    final confirmed = await _reconcileUnknownAlgoOrder(clientAlgoId);
    if (confirmed == null || confirmed.orderId != algoId) {
      throw StateError(
        'Binance acknowledged $type protection (#$algoId), but a fresh open-order read could not confirm it is working.',
      );
    }
    return confirmed;
  }

  LiveOrder? _matchingProtectionOrder(
    List<LiveOrder> orders, {
    required String type,
    required String side,
    required double stopPrice,
    required String? positionSide,
    required Position position,
  }) {
    for (final order in orders) {
      final trigger = order.triggerPrice;
      final tolerance = stopPrice.abs() * 0.0000000001 > 0.00000001
          ? stopPrice.abs() * 0.0000000001
          : 0.00000001;
      final matches =
          order.orderId.isNotEmpty &&
          order.type.toUpperCase() == type &&
          order.side.toUpperCase() == side &&
          _normalizedExchangePositionSide(order.positionSide) ==
              _normalizedExchangePositionSide(positionSide) &&
          trigger != null &&
          (trigger - stopPrice).abs() <= tolerance &&
          _fullyCoversPosition(order, position);
      if (matches) {
        return order;
      }
    }
    return null;
  }

  static String _normalizedExchangePositionSide(String? value) {
    final normalized = value?.trim().toUpperCase() ?? '';
    return normalized == 'BOTH' ? '' : normalized;
  }

  static bool _fullyCoversPosition(LiveOrder order, Position position) {
    if (order.closePosition) {
      return true;
    }
    if (!order.reduceOnly || !order.quantity.isFinite || order.quantity <= 0) {
      return false;
    }
    final tolerance = position.quantity.abs() * 0.00000001;
    return order.quantity + tolerance >= position.quantity;
  }

  Future<LiveOrder?> _reconcileUnknownAlgoOrder(String clientAlgoId) async {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 400),
      Duration(milliseconds: 900),
    ];
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      try {
        final payload = await apiService.getOpenAlgoOrders(symbol: symbol);
        final matches = _parseExchangeOpenAlgoOrders(
          payload,
        ).where((order) => order.clientOrderId == clientAlgoId);
        if (matches.isNotEmpty) {
          return matches.first;
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _exchangePositionSideForPosition(Position position) {
    return switch (_futuresPositionMode) {
      BinanceFuturesPositionMode.oneWay => null,
      BinanceFuturesPositionMode.hedge => position.isLong ? 'LONG' : 'SHORT',
      BinanceFuturesPositionMode.unknown => throw StateError(
        'Binance Futures position mode is unknown; protection routing is blocked.',
      ),
    };
  }

  void _syncLiveRiskTargets({
    StrategyTradePlan? plan,
    bool replaceExisting = false,
  }) {
    final position = _openPosition;
    if (position == null) {
      _clearPlanRiskTargets();
      return;
    }

    final planMatchesSide =
        plan != null &&
        plan.isActionable &&
        ((position.isLong && plan.signal == TradingSignal.buy) ||
            (!position.isLong && plan.signal == TradingSignal.sell));
    if (planMatchesSide) {
      _applyPlanRiskTargets(plan, position);
      return;
    }

    if (!replaceExisting &&
        (_activeTakeProfitPrice != null || _activeStopLossPrice != null)) {
      return;
    }

    _activeTakeProfitPrice = riskSettings.hasTakeProfit
        ? position.takeProfitPrice(
            riskSettings.resolveTakeProfitPercent(
              position.entryPrice,
              quantity: position.quantity,
            ),
          )
        : null;
    _activeStopLossPrice = riskSettings.hasStopLoss
        ? position.stopLossPrice(
            riskSettings.resolveStopLossPercent(
              position.entryPrice,
              quantity: position.quantity,
            ),
          )
        : null;
  }

  void _applyPlanRiskTargets(StrategyTradePlan? plan, Position? position) {
    if (plan == null || position == null || !plan.isActionable) {
      _clearPlanRiskTargets();
      return;
    }

    final takeProfitPercent = riskSettings.resolveTakeProfitPercent(
      position.entryPrice,
      quantity: position.quantity,
      fallbackPercent: plan.takeProfitPercent,
    );
    final stopLossPercent = riskSettings.resolveStopLossPercent(
      position.entryPrice,
      quantity: position.quantity,
      fallbackPercent: plan.stopLossPercent,
    );
    _activeTakeProfitPrice = takeProfitPercent > 0
        ? position.takeProfitPrice(takeProfitPercent)
        : null;
    _activeStopLossPrice = stopLossPercent > 0
        ? position.stopLossPrice(stopLossPercent)
        : null;
  }

  void _clearPlanRiskTargets() {
    _activeTakeProfitPrice = null;
    _activeStopLossPrice = null;
  }

  String _formatExchangeDecimal(double value) {
    return value.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String? _extractRequestIp(String body) {
    final match = RegExp(r'request ip:\s*([0-9a-fA-F\.:]+)').firstMatch(body);
    return match?.group(1);
  }

  void _emitBinanceAccountStatus(BinanceAccountStatus status) {
    _binanceAccountStatus = status;
    if (_binanceAccountController.isClosed) {
      return;
    }
    _binanceAccountController.add(status);
  }

  void _logExecutionBlocked(String message) {
    if (_lastExecutionBlockFingerprint == message) {
      return;
    }
    _lastExecutionBlockFingerprint = message;
    _logConsole(message, level: StrategyConsoleLevel.warning);
  }

  void _executeImmediateManualAction(
    ManualOrderAction action, {
    required double quantity,
    required double executionPrice,
    required ManualOrderType orderType,
    required double requestedPrice,
  }) {
    if (action.isOpenAction) {
      _clearPlanRiskTargets();
    }
    final side = action.positionSide;
    if (action.isOpenAction) {
      _openOrScalePosition(
        side,
        executionPrice,
        quantity,
        'manual',
        orderType: orderType,
        requestedPrice: requestedPrice,
      );
      return;
    }

    _closePositionQuantity(
      expectedSide: side,
      price: executionPrice,
      quantity: quantity,
      reason: 'manual',
      orderType: orderType,
      requestedPrice: requestedPrice,
    );
  }

  void _openOrScalePosition(
    PositionSide desiredSide,
    double price,
    double quantity,
    String reason, {
    ManualOrderType? orderType,
    double? requestedPrice,
  }) {
    if (quantity <= 0) return;

    if (_openPosition == null) {
      _openPosition = Position(
        symbol: symbol,
        side: desiredSide,
        entryPrice: price,
        quantity: quantity,
        entryTime: DateTime.now(),
      );
      _positionController.add(_openPosition);
      _recordEntryTrade(
        desiredSide,
        price,
        quantity,
        reason,
        orderType: orderType,
        requestedPrice: requestedPrice,
      );
      return;
    }

    if (_openPosition!.side == desiredSide) {
      final current = _openPosition!;
      final totalQuantity = current.quantity + quantity;
      final weightedEntry =
          ((current.entryPrice * current.quantity) + (price * quantity)) /
          totalQuantity;
      _openPosition = Position(
        symbol: symbol,
        side: desiredSide,
        entryPrice: weightedEntry,
        quantity: totalQuantity,
        entryTime: current.entryTime,
        liquidationPrice: current.liquidationPrice,
      );
      _positionController.add(_openPosition);
      _recordEntryTrade(
        desiredSide,
        price,
        quantity,
        reason,
        orderType: orderType,
        requestedPrice: requestedPrice,
      );
      return;
    }

    _closePosition(price, reason == 'strategy' ? 'reversal' : reason);
    _openPosition = Position(
      symbol: symbol,
      side: desiredSide,
      entryPrice: price,
      quantity: quantity,
      entryTime: DateTime.now(),
    );
    _positionController.add(_openPosition);
    _recordEntryTrade(
      desiredSide,
      price,
      quantity,
      reason,
      orderType: orderType,
      requestedPrice: requestedPrice,
    );
  }

  void _processPendingManualOrders(double currentPrice) {
    if (_pendingManualOrders.isEmpty) return;

    final orders = List<PendingManualOrder>.from(_pendingManualOrders);
    var changed = false;
    for (final order in orders) {
      if (!_shouldFillOrder(order.action, currentPrice, order.targetPrice)) {
        continue;
      }

      _executeImmediateManualAction(
        order.action,
        quantity: order.quantity,
        executionPrice: order.targetPrice,
        orderType: order.orderType,
        requestedPrice: order.targetPrice,
      );
      _pendingManualOrders.removeWhere((item) => item.id == order.id);
      changed = true;
    }

    if (changed) {
      _emitPendingOrders();
    }
  }

  bool _hasMatchingPosition(ManualOrderAction action) {
    final position = _openPosition;
    if (position == null || !action.isCloseAction) {
      return false;
    }
    return position.side == action.positionSide;
  }

  bool _isMarketable(
    ManualOrderAction action,
    double currentPrice,
    double targetPrice,
  ) {
    return _shouldFillOrder(action, currentPrice, targetPrice);
  }

  bool _shouldFillOrder(
    ManualOrderAction action,
    double currentPrice,
    double targetPrice,
  ) {
    return switch (action) {
      ManualOrderAction.openLong ||
      ManualOrderAction.closeShort => currentPrice <= targetPrice,
      ManualOrderAction.openShort ||
      ManualOrderAction.closeLong => currentPrice >= targetPrice,
    };
  }

  List<double> _buildScaleTargets(double start, double end, int steps) {
    if (!start.isFinite || !end.isFinite || start <= 0 || end <= 0) {
      throw ArgumentError('Scaled order prices must be finite and positive.');
    }
    if (steps <= 1) {
      return [start];
    }
    final stepSize = (end - start) / (steps - 1);
    return List<double>.generate(steps, (index) => start + (stepSize * index));
  }

  void _queuePendingOrder(PendingManualOrder order) {
    _pendingManualOrders.add(order);
    _emitPendingOrders();
  }

  void _emitPendingOrders() {
    if (_pendingOrderController.isClosed) return;
    _pendingOrderController.add(List.unmodifiable(_pendingManualOrders));
  }

  String _nextManualOrderId() {
    _manualOrderSequence += 1;
    return 'manual-${DateTime.now().millisecondsSinceEpoch}-$_manualOrderSequence';
  }

  String _nextClientOrderId(String role) {
    _manualOrderSequence += 1;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final sequence = _manualOrderSequence.toRadixString(36);
    return 'ifut-$role-$clientOrderOwnerId-$timestamp-$sequence';
  }

  Future<void> _loadPersistedTrades() async {
    if (_hasLoadedTrades) return;
    _hasLoadedTrades = true;
    try {
      final persisted = await tradeHistoryService.loadTrades(symbol);
      if (persisted.isNotEmpty) {
        _trades = persisted;
        _accountTrades = persisted;
        _tradeController.add(_trades);
        _accountTradeController.add(_accountTrades);
      }
      _restoreProtectionWindowsFromTrades();
    } catch (e) {
      print('Failed to load trade history: $e');
    }
  }

  void _restoreProtectionWindowsFromTrades() {
    _cooldownUntil = null;
    _protectionLockUntil = null;
    _protectionLockReason = null;

    if (_trades.isEmpty) {
      _emitProtectionStatus(const ProtectionStatus.ready());
      return;
    }

    final exits = _realizedExitTrades(_trades);
    if (exits.isEmpty) {
      _updateProtectionStatus();
      return;
    }

    if (exits.isNotEmpty && riskSettings.hasCooldown) {
      final latestExit = exits.last;
      final cooldownUntil = latestExit.timestamp.add(
        Duration(minutes: riskSettings.cooldownMinutes),
      );
      if (cooldownUntil.isAfter(DateTime.now())) {
        _cooldownUntil = cooldownUntil;
      }
    }

    final pauseDuration = Duration(
      minutes: riskSettings.protectionPauseMinutes,
    );
    var consecutiveLosses = 0;
    final riskBudget = _riskBudgetBaselineUsdt(exits);
    var riskBudgetEquity = riskBudget ?? 0.0;
    var peakRiskBudgetEquity = riskBudgetEquity;

    for (final exit in exits) {
      final pnl = _netProtectionPnl(exit);

      if (pnl < 0) {
        consecutiveLosses += 1;
      } else {
        consecutiveLosses = 0;
      }

      riskBudgetEquity += pnl;
      if (riskBudgetEquity > peakRiskBudgetEquity) {
        peakRiskBudgetEquity = riskBudgetEquity;
      }

      if (riskSettings.hasLossStreakProtection &&
          pnl < 0 &&
          consecutiveLosses >= riskSettings.maxConsecutiveLosses) {
        final lockUntil = exit.timestamp.add(pauseDuration);
        if (lockUntil.isAfter(DateTime.now())) {
          _protectionLockUntil = lockUntil;
          _protectionLockReason =
              'Loss streak lock: ${riskSettings.maxConsecutiveLosses} consecutive losses reached.';
        }
      }

      final drawdownPercent = riskBudget == null
          ? 0.0
          : ((peakRiskBudgetEquity - riskBudgetEquity) / riskBudget) * 100;
      if (riskBudget != null &&
          riskSettings.hasDrawdownProtection &&
          drawdownPercent >= riskSettings.maxDrawdownPercent) {
        final lockUntil = exit.timestamp.add(pauseDuration);
        if (lockUntil.isAfter(DateTime.now())) {
          _protectionLockUntil = lockUntil;
          _protectionLockReason =
              'Risk-budget drawdown lock: net realized drawdown reached ${drawdownPercent.toStringAsFixed(1)}% of the ${_formatUsdt(riskBudget)} risk budget (limit ${riskSettings.maxDrawdownPercent.toStringAsFixed(1)}%).';
        }
      }
    }

    _updateProtectionStatus();
  }

  List<Trade> _realizedExitTrades(List<Trade> trades) {
    return trades
        .where((trade) => trade.kind == 'EXIT' && trade.realizedPnl != null)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  int _consecutiveLossCount() {
    final exits = _realizedExitTrades(_trades);
    var losses = 0;
    for (final trade in exits.reversed) {
      if (_netProtectionPnl(trade) < 0) {
        losses += 1;
      } else {
        break;
      }
    }
    return losses;
  }

  double _currentRealizedDrawdownPercent() {
    final exits = _realizedExitTrades(_trades);
    if (exits.isEmpty) {
      return 0;
    }

    final riskBudget = _riskBudgetBaselineUsdt(exits);
    if (riskBudget == null) {
      return 0;
    }
    var riskBudgetEquity = riskBudget;
    var peakRiskBudgetEquity = riskBudget;
    for (final trade in exits) {
      riskBudgetEquity += _netProtectionPnl(trade);
      if (riskBudgetEquity > peakRiskBudgetEquity) {
        peakRiskBudgetEquity = riskBudgetEquity;
      }
    }

    return ((peakRiskBudgetEquity - riskBudgetEquity) / riskBudget) * 100;
  }

  double _netProtectionPnl(Trade trade) {
    final rawPnl = trade.realizedPnl;
    final grossPnl = rawPnl != null && rawPnl.isFinite ? rawPnl : 0.0;
    final rawFee = trade.fee;
    final fee = rawFee != null && rawFee.isFinite ? rawFee.abs() : 0.0;
    return grossPnl - fee;
  }

  double? _riskBudgetBaselineUsdt(List<Trade> exits) {
    final configuredBudget = riskSettings.investmentUsdt;
    if (configuredBudget != null &&
        configuredBudget.isFinite &&
        configuredBudget > 0) {
      return configuredBudget;
    }

    final leverage = riskSettings.leverage > 0 ? riskSettings.leverage : 1;
    for (final exit in exits) {
      final implicitMargin = (exit.price * exit.quantity.abs()) / leverage;
      if (implicitMargin.isFinite && implicitMargin > 0) {
        return implicitMargin;
      }
    }
    return null;
  }

  void _applyExitProtections(Trade exitTrade) {
    if (riskSettings.hasCooldown) {
      _cooldownUntil = exitTrade.timestamp.add(
        Duration(minutes: riskSettings.cooldownMinutes),
      );
    }

    final pauseDuration = Duration(
      minutes: riskSettings.protectionPauseMinutes,
    );
    if (riskSettings.hasLossStreakProtection &&
        _consecutiveLossCount() >= riskSettings.maxConsecutiveLosses &&
        _netProtectionPnl(exitTrade) < 0) {
      _protectionLockUntil = exitTrade.timestamp.add(pauseDuration);
      _protectionLockReason =
          'Loss streak lock: ${riskSettings.maxConsecutiveLosses} consecutive losses reached.';
      _logConsole(_protectionLockReason!, level: StrategyConsoleLevel.warning);
    }

    final currentDrawdown = _currentRealizedDrawdownPercent();
    if (riskSettings.hasDrawdownProtection &&
        currentDrawdown >= riskSettings.maxDrawdownPercent) {
      final riskBudget = _riskBudgetBaselineUsdt(_realizedExitTrades(_trades));
      _protectionLockUntil = exitTrade.timestamp.add(pauseDuration);
      _protectionLockReason =
          'Risk-budget drawdown lock: net realized drawdown reached ${currentDrawdown.toStringAsFixed(1)}%${riskBudget == null ? '' : ' of the ${_formatUsdt(riskBudget)} risk budget'} (limit ${riskSettings.maxDrawdownPercent.toStringAsFixed(1)}%).';
      _logConsole(_protectionLockReason!, level: StrategyConsoleLevel.warning);
    }

    _updateProtectionStatus(now: exitTrade.timestamp);
  }

  String? _activeProtectionMessage() {
    _updateProtectionStatus();
    return _protectionStatus.isBlocking ? _protectionStatus.message : null;
  }

  void _updateProtectionStatus({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (_cooldownUntil != null && !_cooldownUntil!.isAfter(currentTime)) {
      _cooldownUntil = null;
    }
    if (_protectionLockUntil != null &&
        !_protectionLockUntil!.isAfter(currentTime)) {
      _protectionLockUntil = null;
      _protectionLockReason = null;
    }

    if (_protectionLockUntil != null) {
      _emitProtectionStatus(
        ProtectionStatus.locked(
          until: _protectionLockUntil!,
          message:
              '${_protectionLockReason ?? 'Protection lock active.'} Trading resumes at ${_formatProtectionTime(_protectionLockUntil!)}.',
        ),
      );
      return;
    }

    if (_cooldownUntil != null) {
      _emitProtectionStatus(
        ProtectionStatus.cooldown(
          until: _cooldownUntil!,
          message:
              'Cooldown active until ${_formatProtectionTime(_cooldownUntil!)}.',
        ),
      );
      return;
    }

    _emitProtectionStatus(
      const ProtectionStatus.ready(
        message: 'Protection engine is clear. Auto entries are allowed.',
      ),
    );
  }

  void _emitProtectionStatus(ProtectionStatus status) {
    _protectionStatus = status;
    if (_protectionController.isClosed) {
      return;
    }
    _protectionController.add(status);
  }

  String _formatProtectionTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  _ExchangeAccountSummary _parseExchangeAccountSummary(
    Map<String, dynamic> payload,
  ) {
    final positions = payload['positions'];
    final openPositionCount = positions is List
        ? positions.where((item) {
            if (item is! Map) {
              return false;
            }
            final amount = _asDouble(item['positionAmt']);
            return amount != null && amount.abs() > 0.0000001;
          }).length
        : null;

    return _ExchangeAccountSummary(
      walletBalance: _asDouble(payload['totalWalletBalance']),
      availableBalance: _asDouble(payload['availableBalance']),
      openPositionCount: openPositionCount,
    );
  }

  Position? _parseExchangePosition(List<dynamic> payload) {
    final matches = <Position>[];

    for (final item in payload) {
      if (item is! Map) {
        continue;
      }

      final symbolValue = item['symbol']?.toString().toUpperCase();
      if (symbolValue != symbol.toUpperCase()) {
        continue;
      }

      final amount = _asDouble(item['positionAmt']);
      if (amount == null || amount == 0) {
        continue;
      }

      final entryPrice = _asDouble(item['entryPrice']) ?? 0;
      final liquidationPrice = _asDouble(item['liquidationPrice']);
      final updateTime = _asInt(item['updateTime']) ?? 0;
      final entryTime = updateTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(updateTime)
          : DateTime.now();
      final positionSideValue =
          item['positionSide']?.toString().toUpperCase() ?? '';
      final side = switch (positionSideValue) {
        'LONG' => PositionSide.long,
        'SHORT' => PositionSide.short,
        _ => amount > 0 ? PositionSide.long : PositionSide.short,
      };

      matches.add(
        Position(
          symbol: symbol,
          side: side,
          entryPrice: entryPrice,
          quantity: amount.abs(),
          entryTime: entryTime,
          liquidationPrice: liquidationPrice != null && liquidationPrice > 0
              ? liquidationPrice
              : null,
        ),
      );
    }

    if (matches.isEmpty) {
      return null;
    }

    matches.sort((left, right) => right.quantity.compareTo(left.quantity));
    return matches.first;
  }

  List<Trade> _parseExchangeTrades(
    List<dynamic> payload, {
    String? symbolFilter,
  }) {
    final trades = <Trade>[];
    final normalizedSymbolFilter = symbolFilter == null
        ? null
        : symbolFilter.toUpperCase();

    for (final item in payload) {
      if (item is! Map) {
        continue;
      }

      final symbolValue = item['symbol']?.toString().toUpperCase();
      if (symbolValue == null ||
          (normalizedSymbolFilter != null &&
              symbolValue != normalizedSymbolFilter)) {
        continue;
      }

      final price = _asDouble(item['price']);
      final quantity = _asDouble(item['qty'] ?? item['quantity']);
      if (price == null || quantity == null || quantity <= 0) {
        continue;
      }

      final side = item['side']?.toString().toUpperCase() == 'SELL'
          ? 'SELL'
          : 'BUY';
      final realizedPnl = _asDouble(item['realizedPnl']);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        _asInt(item['time']) ?? DateTime.now().millisecondsSinceEpoch,
      );
      final isRealizedExit =
          realizedPnl != null && realizedPnl.abs() > 0.0000001;
      final maker = item['maker'] == true;

      trades.add(
        Trade(
          symbol: symbolValue,
          side: side,
          price: price,
          quantity: quantity,
          timestamp: timestamp,
          orderId: item['orderId']?.toString() ?? item['id']?.toString(),
          status: 'filled',
          fee: _asDouble(item['commission'])?.abs(),
          strategy: 'Binance Live',
          kind: isRealizedExit ? 'EXIT' : 'LIVE',
          realizedPnl: realizedPnl,
          orderType: maker ? 'Maker' : 'Taker',
          requestedPrice: price,
          reason: 'exchange_sync',
        ),
      );
    }

    trades.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return trades;
  }

  List<LiveOrder> _parseExchangeOpenOrders(List<dynamic> payload) {
    final orders = <LiveOrder>[];

    for (final item in payload) {
      if (item is! Map) {
        continue;
      }

      final orderSymbol = item['symbol']?.toString().toUpperCase();
      if (orderSymbol == null || orderSymbol != symbol.toUpperCase()) {
        continue;
      }

      final closePosition =
          item['closePosition'] == true ||
          '${item['closePosition'] ?? ''}'.toLowerCase() == 'true';
      final quantity = _asDouble(item['origQty'] ?? item['quantity']) ?? 0;
      if (!closePosition && quantity <= 0) {
        continue;
      }

      final price = _asDouble(item['price']) ?? 0;
      final stopPrice = _asDouble(item['stopPrice']);
      final updateTime =
          _asInt(item['updateTime']) ?? _asInt(item['time']) ?? 0;

      orders.add(
        LiveOrder(
          symbol: orderSymbol,
          orderId: item['orderId']?.toString() ?? '',
          clientOrderId: item['clientOrderId']?.toString(),
          side: item['side']?.toString().toUpperCase() ?? 'BUY',
          type: item['type']?.toString().toUpperCase() ?? 'LIMIT',
          price: price,
          stopPrice: stopPrice,
          quantity: quantity,
          reduceOnly: item['reduceOnly'] == true,
          closePosition: closePosition,
          positionSide: item['positionSide']?.toString().toUpperCase(),
          timeInForce: item['timeInForce']?.toString(),
          updatedAt: updateTime > 0
              ? DateTime.fromMillisecondsSinceEpoch(updateTime)
              : DateTime.now(),
        ),
      );
    }

    orders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return orders;
  }

  List<LiveOrder> _parseExchangeOpenAlgoOrders(List<dynamic> payload) {
    final orders = <LiveOrder>[];

    for (final item in payload) {
      if (item is! Map) {
        continue;
      }
      final orderSymbol = item['symbol']?.toString().toUpperCase();
      if (orderSymbol == null || orderSymbol != symbol.toUpperCase()) {
        continue;
      }
      final closePosition =
          item['closePosition'] == true ||
          '${item['closePosition'] ?? ''}'.toLowerCase() == 'true';
      final quantity = _asDouble(item['quantity']) ?? 0;
      if (!closePosition && quantity <= 0) {
        continue;
      }
      final updateTime =
          _asInt(item['updateTime']) ?? _asInt(item['createTime']) ?? 0;
      orders.add(
        LiveOrder(
          symbol: orderSymbol,
          orderId: item['algoId']?.toString() ?? '',
          clientOrderId: item['clientAlgoId']?.toString(),
          isAlgo: true,
          side: item['side']?.toString().toUpperCase() ?? 'BUY',
          type: item['orderType']?.toString().toUpperCase() ?? 'STOP_MARKET',
          price: _asDouble(item['price']) ?? 0,
          stopPrice: _asDouble(item['triggerPrice']),
          quantity: quantity,
          reduceOnly: item['reduceOnly'] == true,
          closePosition: closePosition,
          positionSide: item['positionSide']?.toString().toUpperCase(),
          timeInForce: item['timeInForce']?.toString(),
          updatedAt: updateTime > 0
              ? DateTime.fromMillisecondsSinceEpoch(updateTime)
              : DateTime.now(),
        ),
      );
    }

    orders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return orders;
  }

  static List<String> _normalizeTrackedSymbols(
    String currentSymbol,
    List<String> trackedSymbols,
  ) {
    final normalized = <String>{currentSymbol.toUpperCase()};
    for (final symbol in trackedSymbols) {
      final value = symbol.trim().toUpperCase();
      if (value.isEmpty) {
        continue;
      }
      normalized.add(value);
    }
    return normalized.toList(growable: false);
  }

  static String _normalizeClientOrderOwnerId(String value) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]{8}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'clientOrderOwnerId',
        'Must contain exactly eight lowercase letters or digits.',
      );
    }
    return normalized;
  }

  bool _samePosition(Position? a, Position? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return a == b;
    }

    return a.symbol == b.symbol &&
        a.side == b.side &&
        (a.entryPrice - b.entryPrice).abs() < 0.0000001 &&
        (a.quantity - b.quantity).abs() < 0.0000001 &&
        ((a.liquidationPrice ?? 0) - (b.liquidationPrice ?? 0)).abs() <
            0.0000001;
  }

  bool _sameTrades(List<Trade> a, List<Trade> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.orderId != right.orderId ||
          left.side != right.side ||
          (left.price - right.price).abs() > 0.0000001 ||
          (left.quantity - right.quantity).abs() > 0.0000001 ||
          left.timestamp != right.timestamp ||
          left.kind != right.kind ||
          left.status != right.status ||
          (left.realizedPnl ?? 0) != (right.realizedPnl ?? 0)) {
        return false;
      }
    }
    return true;
  }

  bool _sameOpenOrders(List<LiveOrder> a, List<LiveOrder> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.orderId != right.orderId ||
          left.clientOrderId != right.clientOrderId ||
          left.isAlgo != right.isAlgo ||
          left.side != right.side ||
          left.type != right.type ||
          (left.price - right.price).abs() > 0.0000001 ||
          ((left.stopPrice ?? 0) - (right.stopPrice ?? 0)).abs() > 0.0000001 ||
          (left.quantity - right.quantity).abs() > 0.0000001 ||
          left.reduceOnly != right.reduceOnly ||
          left.closePosition != right.closePosition ||
          left.positionSide != right.positionSide) {
        return false;
      }
    }
    return true;
  }

  void _logPlan(StrategyTradePlan? plan, TradingSignal signal) {
    final fingerprint = plan == null
        ? 'signal:$signal'
        : '${plan.strategyName}|${plan.summaryLabel}|${plan.rationale}';
    if (_lastLoggedPlanFingerprint == fingerprint) {
      return;
    }
    _lastLoggedPlanFingerprint = fingerprint;

    if (plan == null) {
      _logConsole(
        'Strategy updated signal to ${signal.name.toUpperCase()}.',
        level: signal == TradingSignal.hold
            ? StrategyConsoleLevel.info
            : StrategyConsoleLevel.success,
      );
      return;
    }

    final target = plan.targetEntryPrice == null
        ? '--'
        : plan.targetEntryPrice!.toStringAsFixed(
            plan.targetEntryPrice! >= 100 ? 2 : 6,
          );
    final sizeBits = <String>[
      if (plan.quantity != null) 'Qty ${_formatQuantity(plan.quantity!)}',
      if (plan.plannedNotional != null)
        'Exposure ${_formatUsdt(plan.plannedNotional!)}',
      if (plan.estimatedMarginRequired != null)
        'Margin ${_formatUsdt(plan.estimatedMarginRequired!)}',
    ];
    final riskBits = <String>[
      if (plan.takeProfitPercent > 0)
        'TP ${plan.takeProfitPercent.toStringAsFixed(2)}%'
            '${plan.projectedProfitAtTarget == null ? '' : ' (${_formatUsdt(plan.projectedProfitAtTarget!)})'}',
      if (plan.stopLossPercent > 0)
        'SL ${plan.stopLossPercent.toStringAsFixed(2)}%'
            '${plan.projectedLossAtStop == null ? '' : ' (${_formatUsdt(plan.projectedLossAtStop!)})'}',
      '${plan.leverage}x',
    ];
    final segments = <String>[
      '${plan.strategyName}: ${plan.summaryLabel} at $target.',
      if (sizeBits.isNotEmpty) '${sizeBits.join(' | ')}.',
      '${riskBits.join(' | ')}.',
      plan.rationale,
    ];

    _logConsole(
      segments.join(' '),
      level: switch (plan.signal) {
        TradingSignal.buy => StrategyConsoleLevel.success,
        TradingSignal.sell => StrategyConsoleLevel.warning,
        TradingSignal.hold => StrategyConsoleLevel.info,
      },
    );
  }

  void _logConsole(
    String message, {
    StrategyConsoleLevel level = StrategyConsoleLevel.info,
  }) {
    if (message.trim().isEmpty) {
      return;
    }

    _consoleEntries = [
      ..._consoleEntries,
      StrategyConsoleEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message.trim(),
      ),
    ];
    if (_consoleEntries.length > 40) {
      _consoleEntries = _consoleEntries.sublist(_consoleEntries.length - 40);
    }
    if (!_consoleLogController.isClosed) {
      _consoleLogController.add(List.unmodifiable(_consoleEntries));
    }
  }

  static String _formatUsdt(double value) {
    final digits = value >= 100
        ? 2
        : value >= 1
        ? 3
        : 6;
    return '${value.toStringAsFixed(digits)} USDT';
  }

  static String _formatQuantity(double value) {
    final digits = value >= 1000
        ? 2
        : value >= 1
        ? 4
        : 6;
    return value.toStringAsFixed(digits);
  }

  static String _formatPriceValue(double value) {
    return value.toStringAsFixed(value >= 100 ? 2 : 6);
  }

  static double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  void _emitOrderBookSnapshot(OrderBookSnapshot? snapshot) {
    if (_orderBookSnapshotController.isClosed) {
      return;
    }
    _orderBookSnapshotController.add(snapshot);
  }

  void _emitOpenOrders() {
    if (_openOrderController.isClosed) {
      return;
    }
    _openOrderController.add(List.unmodifiable(_openOrders));
  }
}

class _AmbiguousEntryIntent {
  final String clientOrderId;
  final DateTime createdAt;
  String? orderId;
  String? lastStatus;
  double executedQuantity = 0;
  int notFoundConfirmations = 0;
  int flatAfterExecutionConfirmations = 0;

  _AmbiguousEntryIntent({required this.clientOrderId, required this.createdAt});
}

class _ExchangeAccountSummary {
  final double? walletBalance;
  final double? availableBalance;
  final int? openPositionCount;

  const _ExchangeAccountSummary({
    this.walletBalance,
    this.availableBalance,
    this.openPositionCount,
  });
}
