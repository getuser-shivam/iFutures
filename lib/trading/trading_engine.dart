import 'dart:async';
import '../models/kline.dart';
import '../models/manual_order.dart';
import '../models/trade.dart';
import '../models/risk_settings.dart';
import '../models/position.dart';
import '../models/binance_account_status.dart';
import '../models/connection_status.dart';
import '../models/order_book_snapshot.dart';
import '../models/protection_status.dart';
import '../models/strategy_console_entry.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import '../services/order_book_analyzer.dart';
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

  List<Kline> _klines = [];
  List<Trade> _trades = [];
  List<Trade> _accountTrades = [];
  List<PendingManualOrder> _pendingManualOrders = [];
  List<StrategyConsoleEntry> _consoleEntries = [];
  bool _isAutoTradingEnabled = false;
  bool _isStreaming = false;
  bool _hasLoadedTrades = false;
  bool _manualOverrideActive = false;
  int _manualOrderSequence = 0;
  Timer? _exchangeSyncTimer;
  Position? _openPosition;
  StreamSubscription? _wsSubscription;
  Timer? _connectionTimer;
  DateTime? _lastMessageAt;
  int? _lastLatencyMs;
  BinanceAccountStatus _binanceAccountStatus;
  double? _walletBalance;
  double? _availableBalance;
  int? _openPositionCount;
  OrderBookSnapshot? _orderBookSnapshot;
  DateTime? _orderBookSyncedAt;
  DateTime? _cooldownUntil;
  DateTime? _protectionLockUntil;
  String? _protectionLockReason;
  ProtectionStatus _protectionStatus = const ProtectionStatus.ready();
  TradingSignal? _lastSignal;
  StrategyTradePlan? _lastDecisionPlan;
  String? _lastLoggedPlanFingerprint;
  String? _lastExecutionBlockFingerprint;

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

  TradingEngine({
    required this.apiService,
    required this.wsService,
    required this.tradeHistoryService,
    required this.strategy,
    required this.riskSettings,
    required this.symbol,
    List<String> trackedSymbols = const [],
  }) : _binanceAccountStatus = BinanceAccountStatus.notConfigured(
         isTestnet: apiService.isTestnet,
       ),
       trackedSymbols = _normalizeTrackedSymbols(symbol, trackedSymbols);

  bool get isStreaming => _isStreaming;
  bool get isTradingEnabled => _isAutoTradingEnabled;
  bool get isManualOverrideActive => _manualOverrideActive;
  Position? get openPosition => _openPosition;
  List<Kline> get klines => _klines;
  List<Trade> get trades => _trades;
  List<Trade> get accountTrades => List.unmodifiable(_accountTrades);
  double? get walletBalance => _walletBalance;
  double? get availableBalance => _availableBalance;
  int? get openPositionCount => _openPositionCount;
  ProtectionStatus get lastProtectionStatus => _protectionStatus;
  List<PendingManualOrder> get pendingManualOrders =>
      List.unmodifiable(_pendingManualOrders);
  List<StrategyConsoleEntry> get consoleEntries =>
      List.unmodifiable(_consoleEntries);
  TradingSignal? get lastSignal => _lastSignal;
  StrategyTradePlan? get lastDecisionPlan => _lastDecisionPlan;
  BinanceAccountStatus get lastBinanceAccountStatus => _binanceAccountStatus;

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
    _emitPendingOrders();
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
        _openPosition = null;
        _tradeController.add(_trades);
        _accountTradeController.add(_accountTrades);
        _positionController.add(_openPosition);
      }
    } else {
      await _loadPersistedTrades();
    }

    // 1. Fetch historical data
    try {
      final historicalData = await apiService.getKlines(
        symbol: symbol,
        limit: 100,
      );
      _klines = historicalData.map((e) => Kline.fromJson(e)).toList();
      _klineController.add(_klines);
      _logConsole('Loaded ${_klines.length} historical candles for $symbol.');
      if (_klines.isNotEmpty) {
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
    _isAutoTradingEnabled = true;
    _manualOverrideActive = false;
    _logConsole('Auto execution armed for ${strategy.name}.');
    if (!_isStreaming) {
      await startMarketData();
    }
  }

  void disableTrading({String reason = 'manual_stop'}) {
    _isAutoTradingEnabled = false;
    _manualOverrideActive = false;
    _logConsole(
      'Auto execution stopped (${reason.replaceAll('_', ' ')}).',
      level: StrategyConsoleLevel.warning,
    );
    if (_openPosition != null && _klines.isNotEmpty) {
      _closePosition(_klines.last.close, reason);
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
        if (_klines.length > 500) _klines.removeAt(0);
      }
    }
    _klineController.add(_klines);
  }

  Future<void> _evaluateStrategy() async {
    try {
      await _refreshOrderBookContextIfNeeded();
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
          ),
        );
        signal = plan.signal;
      } else {
        signal = await strategy.evaluate(_klines);
      }
      print('Strategy signal: $signal');
      _lastSignal = signal;
      _lastDecisionPlan = plan;
      _signalController.add(signal);
      _decisionPlanController.add(plan);
      _logPlan(plan, signal);
      if (!_isAutoTradingEnabled) return;

      if (signal == TradingSignal.buy) {
        _handleSignal(PositionSide.long, plan: plan);
      } else if (signal == TradingSignal.sell) {
        _handleSignal(PositionSide.short, plan: plan);
      }
    } catch (e) {
      _logConsole(
        'Strategy evaluation failed: $e',
        level: StrategyConsoleLevel.error,
      );
      print('Strategy evaluation failed: $e');
    }
  }

  Future<void> refreshStrategyPlan() async {
    await _ensureMarketData();
    _logConsole('Manual strategy refresh requested.');
    await _evaluateStrategy();
  }

  void _handleSignal(PositionSide desiredSide, {StrategyTradePlan? plan}) {
    _handleSignalWithReason(desiredSide, 'strategy', plan: plan);
  }

  Future<void> manualEnterLong() async {
    await _ensureMarketData();
    if (_isExchangeSyncMode) {
      _logExecutionBlocked(
        'Manual long requested, but live order routing is not enabled. Binance sync is read-only right now.',
      );
      return;
    }
    takeManualControl();
    _executeImmediateManualAction(
      ManualOrderAction.openLong,
      quantity: riskSettings.tradeQuantity,
      executionPrice: _klines.last.close,
      orderType: ManualOrderType.market,
      requestedPrice: _klines.last.close,
    );
  }

  Future<void> manualEnterShort() async {
    await _ensureMarketData();
    if (_isExchangeSyncMode) {
      _logExecutionBlocked(
        'Manual short requested, but live order routing is not enabled. Binance sync is read-only right now.',
      );
      return;
    }
    takeManualControl();
    _executeImmediateManualAction(
      ManualOrderAction.openShort,
      quantity: riskSettings.tradeQuantity,
      executionPrice: _klines.last.close,
      orderType: ManualOrderType.market,
      requestedPrice: _klines.last.close,
    );
  }

  Future<void> manualClose() async {
    await _ensureMarketData();
    if (_isExchangeSyncMode) {
      _logExecutionBlocked(
        'Manual close requested, but live order routing is not enabled. Binance sync is read-only right now.',
      );
      return;
    }
    takeManualControl();
    if (_openPosition == null || _klines.isEmpty) return;
    _executeImmediateManualAction(
      _openPosition!.isLong
          ? ManualOrderAction.closeLong
          : ManualOrderAction.closeShort,
      quantity: _openPosition!.quantity,
      executionPrice: _klines.last.close,
      orderType: ManualOrderType.market,
      requestedPrice: _klines.last.close,
    );
  }

  void takeManualControl() {
    _isAutoTradingEnabled = false;
    _manualOverrideActive = true;
    _logConsole(
      'Manual override activated. Auto execution is paused.',
      level: StrategyConsoleLevel.warning,
    );
  }

  Future<ManualOrderSubmissionResult> submitManualOrder(
    ManualOrderRequest request,
  ) async {
    await _ensureMarketData();

    if (_isExchangeSyncMode) {
      _logExecutionBlocked(
        'Manual ticket blocked in read-only Binance sync mode. No simulated trade was created.',
      );
      return const ManualOrderSubmissionResult(
        accepted: false,
        message:
            'Binance sync mode is read-only right now. Real order routing is not enabled, so no local simulated trade was created.',
      );
    }

    if (request.quantity <= 0) {
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
        if (targetPrice == null || targetPrice <= 0) {
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

  Future<void> _ensureMarketData() async {
    if (!_isStreaming) {
      await startMarketData();
    }
  }

  void _handleSignalWithReason(
    PositionSide desiredSide,
    String reason, {
    StrategyTradePlan? plan,
  }) {
    if (_isExchangeSyncMode) {
      _logExecutionBlocked(
        '${strategy.name} signaled ${desiredSide == PositionSide.long ? 'LONG' : 'SHORT'}, but live order routing is not enabled. Waiting for actual Binance account changes instead of simulating a local trade.',
      );
      return;
    }

    if (_klines.isEmpty) {
      print('No price data available for trade execution');
      return;
    }

    final currentPrice = _klines.last.close;
    final protectionMessage = _activeProtectionMessage();
    if (reason == 'strategy' && protectionMessage != null) {
      if (_openPosition != null && _openPosition!.side != desiredSide) {
        _logExecutionBlocked(
          'Protection engine is active: $protectionMessage Closing the current position without opening a reversal.',
        );
        _closePosition(
          currentPrice,
          'protection_flatten',
          orderType: plan?.orderType,
          requestedPrice: plan?.targetEntryPrice,
        );
        return;
      }

      _logExecutionBlocked(
        'Protection engine is active: $protectionMessage New auto entries are paused.',
      );
      return;
    }

    final quantity = riskSettings.tradeQuantity;

    if (quantity <= 0) {
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
          );
    _positionController.add(_openPosition);

    print(
      'Recorded EXIT $exitSide: ${trade.symbol} @ ${trade.price} PnL=$pnl (${trade.reason})',
    );
  }

  void _checkRisk(double currentPrice) {
    final position = _openPosition;
    if (position == null) return;

    if (riskSettings.hasStopLoss) {
      final stopLoss = position.stopLossPrice(riskSettings.stopLossPercent);
      if (position.isLong && currentPrice <= stopLoss) {
        _closePosition(currentPrice, 'stop_loss');
        return;
      }
      if (!position.isLong && currentPrice >= stopLoss) {
        _closePosition(currentPrice, 'stop_loss');
        return;
      }
    }

    if (riskSettings.hasTakeProfit) {
      final takeProfit = position.takeProfitPrice(
        riskSettings.takeProfitPercent,
      );
      if (position.isLong && currentPrice >= takeProfit) {
        _closePosition(currentPrice, 'take_profit');
        return;
      }
      if (!position.isLong && currentPrice <= takeProfit) {
        _closePosition(currentPrice, 'take_profit');
        return;
      }
    }
  }

  void stopMarketData() {
    _isStreaming = false;
    _wsSubscription?.cancel();
    _wsSubscription = null;
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
    stopMarketData();
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

  Future<bool> _loadInitialAccountState() async {
    if (!apiService.hasCredentials) {
      return false;
    }

    return _syncExchangeState(logSuccess: true);
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

  Future<void> _refreshOrderBookContextIfNeeded({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _orderBookSyncedAt != null &&
        now.difference(_orderBookSyncedAt!) < const Duration(minutes: 1)) {
      return;
    }

    try {
      final payload = await apiService.getOrderBook(symbol: symbol, limit: 20);
      final snapshot = OrderBookAnalyzer.analyze(
        payload,
        plannedQuantity: riskSettings.tradeQuantity,
        capturedAt: now,
      );
      final previousCapturedAt = _orderBookSyncedAt;
      _orderBookSnapshot = snapshot;
      _orderBookSyncedAt = now;

      if (previousCapturedAt == null ||
          now.difference(previousCapturedAt) >= const Duration(minutes: 1)) {
        _logConsole(
          'Order book updated: spread ${snapshot.spreadPercent?.toStringAsFixed(4) ?? '--'}%, '
          'imbalance ${snapshot.imbalancePercent.toStringAsFixed(1)}%, '
          'buy slip ${snapshot.estimatedBuySlippagePercent?.toStringAsFixed(4) ?? '--'}%, '
          'sell slip ${snapshot.estimatedSellSlippagePercent?.toStringAsFixed(4) ?? '--'}%. '
          '${snapshot.executionHint}.',
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
    if (!apiService.hasCredentials) {
      _emitBinanceAccountStatus(
        BinanceAccountStatus.notConfigured(
          isTestnet: apiService.isTestnet,
          message: 'Binance API credentials are not configured.',
        ),
      );
      return false;
    }

    try {
      final results = await Future.wait<dynamic>([
        apiService.getPositionRisk(symbol: symbol),
        apiService.getAccountInfo(),
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
      final groupedTrades = <String, List<Trade>>{};
      for (var i = 0; i < trackedSymbols.length; i++) {
        final trackedSymbol = trackedSymbols[i];
        groupedTrades[trackedSymbol] = _parseExchangeTrades(
          results[i + 2] as List<dynamic>,
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

      _openPosition = syncedPosition;
      _trades = syncedTrades;
      _accountTrades = syncedAccountTrades;
      _walletBalance = accountSummary.walletBalance;
      _availableBalance = accountSummary.availableBalance;
      _openPositionCount = accountSummary.openPositionCount;
      _lastExecutionBlockFingerprint = null;
      _positionController.add(_openPosition);
      _tradeController.add(_trades);
      _accountTradeController.add(_accountTrades);
      _restoreProtectionWindowsFromTrades();
      await Future.wait([
        for (final entry in groupedTrades.entries)
          tradeHistoryService.saveTrades(entry.key, entry.value),
      ]);

      if (logSuccess ||
          positionChanged ||
          tradesChanged ||
          accountTradesChanged) {
        final positionLabel = _openPosition == null
            ? 'no open position'
            : '${_openPosition!.isLong ? 'LONG' : 'SHORT'} '
                  '${_formatQuantity(_openPosition!.quantity)} @ '
                  '${_openPosition!.entryPrice.toStringAsFixed(_openPosition!.entryPrice >= 100 ? 2 : 6)}';
        _logConsole(
          'Synced Binance account state: ${_trades.length} ${symbol.toUpperCase()} fills, ${_accountTrades.length} tracked fills total, $positionLabel. Wallet ${_walletBalance?.toStringAsFixed(2) ?? '--'} USDT, available ${_availableBalance?.toStringAsFixed(2) ?? '--'} USDT.',
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
    var cumulativePnl = 0.0;
    var peakPnl = 0.0;

    for (final exit in exits) {
      final pnl = exit.realizedPnl ?? 0;

      if (pnl < 0) {
        consecutiveLosses += 1;
      } else {
        consecutiveLosses = 0;
      }

      cumulativePnl += pnl;
      if (cumulativePnl > peakPnl) {
        peakPnl = cumulativePnl;
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

      final drawdownPercent = peakPnl <= 0
          ? 0.0
          : ((peakPnl - cumulativePnl) / peakPnl) * 100;
      if (riskSettings.hasDrawdownProtection &&
          drawdownPercent >= riskSettings.maxDrawdownPercent) {
        final lockUntil = exit.timestamp.add(pauseDuration);
        if (lockUntil.isAfter(DateTime.now())) {
          _protectionLockUntil = lockUntil;
          _protectionLockReason =
              'Drawdown lock: realized drawdown reached ${drawdownPercent.toStringAsFixed(1)}% (limit ${riskSettings.maxDrawdownPercent.toStringAsFixed(1)}%).';
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
      if ((trade.realizedPnl ?? 0) < 0) {
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

    var cumulativePnl = 0.0;
    var peakPnl = 0.0;
    for (final trade in exits) {
      cumulativePnl += trade.realizedPnl ?? 0;
      if (cumulativePnl > peakPnl) {
        peakPnl = cumulativePnl;
      }
    }

    if (peakPnl <= 0) {
      return 0;
    }

    return ((peakPnl - cumulativePnl) / peakPnl) * 100;
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
        (exitTrade.realizedPnl ?? 0) < 0) {
      _protectionLockUntil = exitTrade.timestamp.add(pauseDuration);
      _protectionLockReason =
          'Loss streak lock: ${riskSettings.maxConsecutiveLosses} consecutive losses reached.';
      _logConsole(_protectionLockReason!, level: StrategyConsoleLevel.warning);
    }

    final currentDrawdown = _currentRealizedDrawdownPercent();
    if (riskSettings.hasDrawdownProtection &&
        currentDrawdown >= riskSettings.maxDrawdownPercent) {
      _protectionLockUntil = exitTrade.timestamp.add(pauseDuration);
      _protectionLockReason =
          'Drawdown lock: realized drawdown reached ${currentDrawdown.toStringAsFixed(1)}% (limit ${riskSettings.maxDrawdownPercent.toStringAsFixed(1)}%).';
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
        return null;
      }

      final entryPrice = _asDouble(item['entryPrice']) ?? 0;
      final updateTime = _asInt(item['updateTime']) ?? 0;
      final entryTime = updateTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(updateTime)
          : DateTime.now();

      return Position(
        symbol: symbol,
        side: amount > 0 ? PositionSide.long : PositionSide.short,
        entryPrice: entryPrice,
        quantity: amount.abs(),
        entryTime: entryTime,
      );
    }

    return null;
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
        (a.quantity - b.quantity).abs() < 0.0000001;
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
