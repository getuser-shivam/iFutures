import 'dart:async';
import '../models/kline.dart';
import '../models/manual_order.dart';
import '../models/trade.dart';
import '../models/risk_settings.dart';
import '../models/position.dart';
import '../models/connection_status.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import '../services/trade_history_service.dart';
import 'strategy.dart';

class TradingEngine {
  final BinanceApiService apiService;
  final BinanceWebSocketService wsService;
  final TradeHistoryService tradeHistoryService;
  final TradingStrategy strategy;
  final RiskSettings riskSettings;
  final String symbol;

  List<Kline> _klines = [];
  List<Trade> _trades = [];
  List<PendingManualOrder> _pendingManualOrders = [];
  bool _isAutoTradingEnabled = false;
  bool _isStreaming = false;
  bool _hasLoadedTrades = false;
  bool _manualOverrideActive = false;
  int _manualOrderSequence = 0;
  Position? _openPosition;
  StreamSubscription? _wsSubscription;
  Timer? _connectionTimer;
  DateTime? _lastMessageAt;
  int? _lastLatencyMs;
  TradingSignal? _lastSignal;
  StrategyTradePlan? _lastDecisionPlan;

  final _klineController = StreamController<List<Kline>>.broadcast();
  final _tradeController = StreamController<List<Trade>>.broadcast();
  final _positionController = StreamController<Position?>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  final _signalController = StreamController<TradingSignal?>.broadcast();
  final _decisionPlanController =
      StreamController<StrategyTradePlan?>.broadcast();
  final _pendingOrderController =
      StreamController<List<PendingManualOrder>>.broadcast();

  Stream<List<Kline>> get klineStream => _klineController.stream;
  Stream<List<Trade>> get tradeStream => _tradeController.stream;
  Stream<Position?> get positionStream => _positionController.stream;
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  Stream<TradingSignal?> get signalStream => _signalController.stream;
  Stream<StrategyTradePlan?> get decisionPlanStream =>
      _decisionPlanController.stream;
  Stream<List<PendingManualOrder>> get pendingOrderStream =>
      _pendingOrderController.stream;

  TradingEngine({
    required this.apiService,
    required this.wsService,
    required this.tradeHistoryService,
    required this.strategy,
    required this.riskSettings,
    required this.symbol,
  });

  bool get isStreaming => _isStreaming;
  bool get isTradingEnabled => _isAutoTradingEnabled;
  bool get isManualOverrideActive => _manualOverrideActive;
  Position? get openPosition => _openPosition;
  List<Kline> get klines => _klines;
  List<Trade> get trades => _trades;
  List<PendingManualOrder> get pendingManualOrders =>
      List.unmodifiable(_pendingManualOrders);
  TradingSignal? get lastSignal => _lastSignal;
  StrategyTradePlan? get lastDecisionPlan => _lastDecisionPlan;

  Future<void> startMarketData() async {
    if (_isStreaming) return;
    _isStreaming = true;
    _positionController.add(_openPosition);
    _connectionController.add(ConnectionStatus.connecting());
    _signalController.add(_lastSignal);
    _decisionPlanController.add(_lastDecisionPlan);
    _emitPendingOrders();
    _startConnectionTicker();
    await _loadPersistedTrades();

    // 1. Fetch historical data
    try {
      final historicalData = await apiService.getKlines(
        symbol: symbol,
        limit: 100,
      );
      _klines = historicalData.map((e) => Kline.fromJson(e)).toList();
      _klineController.add(_klines);
      if (_klines.isNotEmpty) {
        await _evaluateStrategy();
      }
    } catch (e) {
      print('Failed to fetch historical data: $e');
    }

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
    if (!_isStreaming) {
      await startMarketData();
    }
  }

  void disableTrading({String reason = 'manual_stop'}) {
    _isAutoTradingEnabled = false;
    _manualOverrideActive = false;
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
    StrategyTradePlan? plan;
    final strategyCandidate = strategy;
    late final TradingSignal signal;
    if (strategyCandidate case final TradePlanningStrategy planningStrategy) {
      plan = await planningStrategy.buildTradePlan(
        _klines,
        symbol: symbol,
        riskSettings: riskSettings,
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
    if (!_isAutoTradingEnabled) return;

    if (signal == TradingSignal.buy) {
      _handleSignal(PositionSide.long, plan: plan);
    } else if (signal == TradingSignal.sell) {
      _handleSignal(PositionSide.short, plan: plan);
    }
  }

  void _handleSignal(PositionSide desiredSide, {StrategyTradePlan? plan}) {
    _handleSignalWithReason(desiredSide, 'strategy', plan: plan);
  }

  Future<void> manualEnterLong() async {
    await _ensureMarketData();
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
  }

  Future<ManualOrderSubmissionResult> submitManualOrder(
    ManualOrderRequest request,
  ) async {
    await _ensureMarketData();

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
    if (_klines.isEmpty) {
      print('No price data available for trade execution');
      return;
    }

    final currentPrice = _klines.last.close;
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
    _positionController.close();
    _connectionController.close();
    _signalController.close();
    _decisionPlanController.close();
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
    await tradeHistoryService.clearTrades(symbol);
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
        _tradeController.add(_trades);
      }
    } catch (e) {
      print('Failed to load trade history: $e');
    }
  }
}
