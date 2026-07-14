import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/binance_account_status.dart';
import 'package:ifutures/models/connection_status.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/models/manual_order.dart';
import 'package:ifutures/models/protection_status.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/services/binance_api.dart';
import 'package:ifutures/services/binance_ws.dart';
import 'package:ifutures/services/trade_history_service.dart';
import 'package:ifutures/trading/manual_strategy.dart';
import 'package:ifutures/trading/strategy.dart';
import 'package:ifutures/trading/trading_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBinanceApiService extends BinanceApiService {
  final List<dynamic> positionRiskPayload;
  final List<dynamic> userTradesPayload;
  final List<dynamic> openOrdersPayload;
  final List<dynamic> openAlgoOrdersPayload;
  final Map<String, List<dynamic>> userTradesBySymbol;
  final Map<String, dynamic> accountInfoPayload;
  final BinanceFuturesPositionMode positionMode;
  final void Function(Map<String, dynamic> order)? onPlaceOrder;
  final Duration placeOrderDelay;
  final bool publishPlacedAlgoOrders;
  final Map<String, Map<String, dynamic>> orderLookupResponses;
  Completer<void>? accountInfoGate;
  int unknownOrderSubmissionsRemaining;
  int userDataStartFailuresRemaining;
  final List<Map<String, dynamic>> placedOrders = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> cancelledOrders = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> cancelledAlgoOrders =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> leverageUpdates = <Map<String, dynamic>>[];
  int positionModeRequests = 0;
  int orderLookupRequests = 0;
  int userDataStartRequests = 0;

  _FakeBinanceApiService({
    String apiKey = '',
    String apiSecret = '',
    bool isTestnet = true,
    this.positionRiskPayload = const <dynamic>[],
    this.userTradesPayload = const <dynamic>[],
    List<dynamic> openOrdersPayload = const <dynamic>[],
    List<dynamic> openAlgoOrdersPayload = const <dynamic>[],
    this.userTradesBySymbol = const <String, List<dynamic>>{},
    this.accountInfoPayload = const <String, dynamic>{
      'totalWalletBalance': '0',
      'availableBalance': '0',
      'positions': <dynamic>[],
    },
    this.positionMode = BinanceFuturesPositionMode.oneWay,
    this.onPlaceOrder,
    this.placeOrderDelay = Duration.zero,
    this.publishPlacedAlgoOrders = true,
    this.unknownOrderSubmissionsRemaining = 0,
    this.userDataStartFailuresRemaining = 0,
    Map<String, Map<String, dynamic>> orderLookupResponses = const {},
  }) : openOrdersPayload = List<dynamic>.from(openOrdersPayload),
       openAlgoOrdersPayload = List<dynamic>.from(openAlgoOrdersPayload),
       orderLookupResponses = Map<String, Map<String, dynamic>>.from(
         orderLookupResponses,
       ),
       super(apiKey: apiKey, apiSecret: apiSecret, isTestnet: isTestnet);

  @override
  Future<List<dynamic>> getKlines({
    required String symbol,
    String interval = '1m',
    int? limit,
  }) async {
    return [_klineJson(0, 1.0), _klineJson(1, 1.1), _klineJson(2, 1.2)];
  }

  @override
  Future<List<dynamic>> getPositionRisk({String? symbol}) async {
    return positionRiskPayload;
  }

  @override
  Future<List<dynamic>> getOpenOrders({String? symbol}) async {
    return openOrdersPayload;
  }

  @override
  Future<List<dynamic>> getOpenAlgoOrders({String? symbol}) async {
    return openAlgoOrdersPayload;
  }

  @override
  Future<List<dynamic>> getUserTrades({
    required String symbol,
    int limit = 100,
  }) async {
    if (userTradesBySymbol.isNotEmpty) {
      return userTradesBySymbol[symbol.toUpperCase()] ?? const <dynamic>[];
    }
    return userTradesPayload;
  }

  @override
  Future<Map<String, dynamic>> getAccountInfo() async {
    await accountInfoGate?.future;
    return accountInfoPayload;
  }

  @override
  Future<String> startUserDataStream() async {
    userDataStartRequests += 1;
    if (userDataStartFailuresRemaining > 0) {
      userDataStartFailuresRemaining -= 1;
      throw StateError('temporary listen-key failure');
    }
    return 'fake-listen-key';
  }

  @override
  Future<void> keepAliveUserDataStream(String listenKey) async {}

  @override
  Future<void> closeUserDataStream(String listenKey) async {}

  @override
  Future<BinanceFuturesPositionMode> getPositionMode() async {
    positionModeRequests += 1;
    return positionMode;
  }

  @override
  Future<Map<String, dynamic>> getExchangeInfo() async {
    return <String, dynamic>{
      'symbols': <Map<String, dynamic>>[
        <String, dynamic>{
          'symbol': 'TRUUSDT',
          'status': 'TRADING',
          'contractType': 'PERPETUAL',
          'quantityPrecision': 2,
          'pricePrecision': 6,
          'filters': <Map<String, dynamic>>[
            <String, dynamic>{
              'filterType': 'PRICE_FILTER',
              'tickSize': '0.000001',
            },
            <String, dynamic>{
              'filterType': 'LOT_SIZE',
              'stepSize': '0.01',
              'minQty': '0.01',
            },
            <String, dynamic>{'filterType': 'MIN_NOTIONAL', 'notional': '5'},
          ],
        },
        <String, dynamic>{
          'symbol': 'GALAUSDT',
          'status': 'TRADING',
          'contractType': 'PERPETUAL',
          'quantityPrecision': 2,
          'pricePrecision': 4,
          'filters': <Map<String, dynamic>>[
            <String, dynamic>{
              'filterType': 'PRICE_FILTER',
              'tickSize': '0.0001',
            },
            <String, dynamic>{
              'filterType': 'LOT_SIZE',
              'stepSize': '0.01',
              'minQty': '0.01',
            },
            <String, dynamic>{'filterType': 'MIN_NOTIONAL', 'notional': '5'},
          ],
        },
        <String, dynamic>{
          'symbol': 'TRIAUSDT',
          'status': 'TRADING',
          'contractType': 'PERPETUAL',
          'quantityPrecision': 2,
          'pricePrecision': 6,
          'filters': <Map<String, dynamic>>[
            <String, dynamic>{
              'filterType': 'PRICE_FILTER',
              'tickSize': '0.000001',
            },
            <String, dynamic>{
              'filterType': 'LOT_SIZE',
              'stepSize': '0.01',
              'minQty': '0.01',
            },
            <String, dynamic>{'filterType': 'MIN_NOTIONAL', 'notional': '5'},
          ],
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> placeOrder({
    required String symbol,
    required String side,
    required String type,
    String? quantity,
    String? price,
    String? stopPrice,
    String? timeInForce,
    String? positionSide,
    bool? closePosition,
    bool? reduceOnly,
    String? newClientOrderId,
    String? newOrderRespType,
    Map<String, dynamic>? extraParams,
  }) async {
    final order = <String, dynamic>{
      'symbol': symbol,
      'side': side,
      'type': type,
      'quantity': quantity,
      'price': price,
      'stopPrice': stopPrice,
      'timeInForce': timeInForce,
      'positionSide': positionSide,
      'closePosition': closePosition,
      'reduceOnly': reduceOnly,
      'newClientOrderId': newClientOrderId,
    };
    placedOrders.add(order);
    if (placeOrderDelay > Duration.zero) {
      await Future<void>.delayed(placeOrderDelay);
    }
    onPlaceOrder?.call(order);
    if (unknownOrderSubmissionsRemaining > 0) {
      unknownOrderSubmissionsRemaining -= 1;
      throw BinanceRequestOutcomeUnknownException(
        statusCode: 503,
        body: '{"code":-1000,"msg":"Execution status unknown."}',
        method: 'POST',
        path: '/fapi/v1/order',
        scope: BinanceApiScope.futures,
        requestUri: Uri.parse('https://demo-fapi.binance.com/fapi/v1/order'),
        headers: const <String, String>{},
        clientOrderId: newClientOrderId,
      );
    }
    final orderId = 'fake-${placedOrders.length}';
    final response = <String, dynamic>{
      'orderId': orderId,
      'clientOrderId': newClientOrderId,
      'status': type == 'MARKET' ? 'FILLED' : 'NEW',
      'executedQty': type == 'MARKET' ? quantity ?? '0' : '0',
    };
    if (newClientOrderId != null) {
      orderLookupResponses[newClientOrderId] = Map<String, dynamic>.from(
        response,
      );
    }
    return response;
  }

  @override
  Future<Map<String, dynamic>> getOrderByClientOrderId({
    required String symbol,
    required String origClientOrderId,
  }) async {
    orderLookupRequests += 1;
    final response = orderLookupResponses[origClientOrderId];
    if (response != null) {
      return Map<String, dynamic>.from(response);
    }
    throw BinanceApiException(
      statusCode: 400,
      body: '{"code":-2013,"msg":"Order does not exist."}',
      method: 'GET',
      path: '/fapi/v1/order',
      scope: BinanceApiScope.futures,
      requestUri: Uri.parse('https://demo-fapi.binance.com/fapi/v1/order'),
      headers: const <String, String>{},
      clientOrderId: origClientOrderId,
    );
  }

  @override
  Future<Map<String, dynamic>> cancelOrder({
    required String symbol,
    required String orderId,
  }) async {
    cancelledOrders.add(<String, dynamic>{
      'symbol': symbol,
      'orderId': orderId,
    });
    openOrdersPayload.removeWhere(
      (item) => '${item['orderId'] ?? ''}' == orderId,
    );
    for (final entry in orderLookupResponses.entries.toList()) {
      if ('${entry.value['orderId'] ?? ''}' == orderId) {
        orderLookupResponses[entry.key] = <String, dynamic>{
          ...entry.value,
          'status': 'CANCELED',
        };
      }
    }
    return <String, dynamic>{'orderId': orderId, 'symbol': symbol};
  }

  @override
  Future<Map<String, dynamic>> placeAlgoOrder({
    required String symbol,
    required String side,
    required String type,
    required String triggerPrice,
    String? positionSide,
    bool closePosition = true,
    String workingType = 'MARK_PRICE',
    bool priceProtect = true,
    String? clientAlgoId,
    String newOrderRespType = 'ACK',
  }) async {
    final order = <String, dynamic>{
      'symbol': symbol,
      'side': side,
      'type': type,
      'triggerPrice': triggerPrice,
      'positionSide': positionSide,
      'closePosition': closePosition,
      'workingType': workingType,
      'priceProtect': priceProtect,
      'clientAlgoId': clientAlgoId,
    };
    placedOrders.add(order);
    onPlaceOrder?.call(order);
    final algoId = 'fake-algo-${placedOrders.length}';
    if (publishPlacedAlgoOrders) {
      openAlgoOrdersPayload.add(<String, dynamic>{
        'symbol': symbol,
        'algoId': algoId,
        'clientAlgoId': clientAlgoId,
        'side': side,
        'orderType': type,
        'triggerPrice': triggerPrice,
        'positionSide': positionSide ?? 'BOTH',
        'closePosition': closePosition,
        'quantity': '0',
        'reduceOnly': false,
        'timeInForce': 'GTC',
        'updateTime': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return <String, dynamic>{'algoId': algoId, 'clientAlgoId': clientAlgoId};
  }

  @override
  Future<Map<String, dynamic>> cancelAlgoOrder({required String algoId}) async {
    cancelledAlgoOrders.add(<String, dynamic>{'algoId': algoId});
    openAlgoOrdersPayload.removeWhere(
      (item) => '${item['algoId'] ?? ''}' == algoId,
    );
    return <String, dynamic>{'algoId': algoId, 'code': '200'};
  }

  @override
  Future<Map<String, dynamic>> setLeverage({
    required String symbol,
    required int leverage,
  }) async {
    leverageUpdates.add(<String, dynamic>{
      'symbol': symbol,
      'leverage': leverage,
    });
    return <String, dynamic>{'leverage': leverage};
  }
}

class _FakeBinanceWebSocketService extends BinanceWebSocketService {
  final _controller = StreamController<dynamic>.broadcast();
  final _userDataController = StreamController<dynamic>.broadcast();

  _FakeBinanceWebSocketService() : super();

  @override
  Stream<dynamic> subscribeToKlines(
    String symbol, {
    String interval = '1m',
    void Function(ConnectionStatus status)? onStatusChanged,
  }) {
    onStatusChanged?.call(ConnectionStatus.connected());
    return _controller.stream;
  }

  @override
  Stream<dynamic> subscribeToUserData(
    String listenKey, {
    void Function(ConnectionStatus status)? onStatusChanged,
  }) {
    return _userDataController.stream;
  }

  void emitUserDataError(Object error) {
    _userDataController.addError(error);
  }

  void emitUserDataEvent(Map<String, dynamic> event) {
    _userDataController.add(event);
  }

  void emitKline(int minute, double close) {
    final openTime = DateTime(2026, 3, 20, 0, minute);
    final closeTime = openTime.add(const Duration(minutes: 1));
    _controller.add({
      'E': closeTime.millisecondsSinceEpoch,
      'k': {
        't': openTime.millisecondsSinceEpoch,
        'T': closeTime.millisecondsSinceEpoch,
        'o': close.toStringAsFixed(4),
        'h': close.toStringAsFixed(4),
        'l': close.toStringAsFixed(4),
        'c': close.toStringAsFixed(4),
        'v': '100',
        'x': true,
      },
    });
  }

  void dispose() {
    _controller.close();
    _userDataController.close();
  }
}

class _AlwaysBuyStrategy extends TradingStrategy
    implements TradePlanningStrategy {
  @override
  String get name => 'Always Buy';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    return TradingSignal.buy;
  }

  @override
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) async {
    final currentPrice = history.last.close;
    final config =
        riskSettings ??
        const RiskSettings(
          stopLossPercent: 0,
          takeProfitPercent: 0,
          tradeQuantity: 1,
        );

    return StrategyTradePlan(
      strategyName: name,
      signal: TradingSignal.buy,
      orderType: ManualOrderType.market,
      currentPrice: currentPrice,
      targetEntryPrice: currentPrice,
      leverage: config.leverage,
      takeProfitPercent: config.takeProfitPercent,
      stopLossPercent: config.stopLossPercent,
      rationale: 'Test strategy always requests a long entry.',
      generatedAt: DateTime.now(),
      quantity: config.tradeQuantity,
    );
  }
}

class _AlwaysSellStrategy extends TradingStrategy
    implements TradePlanningStrategy {
  @override
  String get name => 'Always Sell';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    return TradingSignal.sell;
  }

  @override
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) async {
    final currentPrice = history.last.close;
    final config =
        riskSettings ??
        const RiskSettings(
          stopLossPercent: 0,
          takeProfitPercent: 0,
          tradeQuantity: 1,
        );
    return StrategyTradePlan(
      strategyName: name,
      signal: TradingSignal.sell,
      orderType: ManualOrderType.market,
      currentPrice: currentPrice,
      targetEntryPrice: currentPrice,
      leverage: config.leverage,
      takeProfitPercent: config.takeProfitPercent,
      stopLossPercent: config.stopLossPercent,
      rationale: 'Test strategy always requests a short entry.',
      generatedAt: DateTime.now(),
      quantity: config.tradeQuantity,
    );
  }
}

class _PlannedTakeProfitBuyStrategy extends TradingStrategy
    implements TradePlanningStrategy {
  @override
  String get name => 'Planned TP Buy';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    return TradingSignal.buy;
  }

  @override
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) async {
    final currentPrice = history.last.close;
    return StrategyTradePlan(
      strategyName: name,
      signal: TradingSignal.buy,
      orderType: ManualOrderType.market,
      currentPrice: currentPrice,
      targetEntryPrice: currentPrice,
      leverage: riskSettings?.leverage ?? 1,
      takeProfitPercent: 5,
      stopLossPercent: 0,
      rationale: 'Uses the plan-defined take profit.',
      generatedAt: DateTime.now(),
      quantity: riskSettings?.tradeQuantity ?? 1,
    );
  }
}

class _LeveragedBuyStrategy extends TradingStrategy
    implements TradePlanningStrategy {
  final int planLeverage;
  final double planStopLossPercent;

  _LeveragedBuyStrategy({
    required this.planLeverage,
    required this.planStopLossPercent,
  });

  @override
  String get name => 'Leveraged Buy';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    return TradingSignal.buy;
  }

  @override
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) async {
    final currentPrice = history.last.close;
    return StrategyTradePlan(
      strategyName: name,
      signal: TradingSignal.buy,
      orderType: ManualOrderType.market,
      currentPrice: currentPrice,
      targetEntryPrice: currentPrice,
      leverage: planLeverage,
      takeProfitPercent: 1,
      stopLossPercent: planStopLossPercent,
      rationale: 'Exercises plan-specific leverage risk validation.',
      generatedAt: DateTime.now(),
      quantity: riskSettings?.tradeQuantity ?? 1,
    );
  }
}

List<dynamic> _klineJson(int minute, double close) {
  final openTime = DateTime(2026, 3, 20, 0, minute);
  final closeTime = openTime.add(const Duration(minutes: 1));
  return [
    openTime.millisecondsSinceEpoch,
    close.toStringAsFixed(4),
    close.toStringAsFixed(4),
    close.toStringAsFixed(4),
    close.toStringAsFixed(4),
    '100',
    closeTime.millisecondsSinceEpoch,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'manual entry disables auto trading and keeps the position open',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final engine = TradingEngine(
        apiService: _FakeBinanceApiService(),
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 0,
          takeProfitPercent: 0,
          tradeQuantity: 1,
        ),
        symbol: 'GALAUSDT',
      );

      await engine.enableTrading();
      expect(engine.isTradingEnabled, isTrue);

      await engine.manualEnterLong();

      expect(engine.isTradingEnabled, isFalse);
      expect(engine.isManualOverrideActive, isTrue);
      expect(engine.openPosition, isNotNull);
      expect(engine.openPosition!.isLong, isTrue);
      expect(engine.trades, hasLength(1));
      expect(engine.trades.single.reason, 'manual');

      engine.dispose();
      wsService.dispose();
    },
  );

  test('limit order queues and later fills from market data', () async {
    final wsService = _FakeBinanceWebSocketService();
    final engine = TradingEngine(
      apiService: _FakeBinanceApiService(),
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 0,
        takeProfitPercent: 0,
        tradeQuantity: 1,
      ),
      symbol: 'GALAUSDT',
    );

    final result = await engine.submitManualOrder(
      const ManualOrderRequest(
        action: ManualOrderAction.openLong,
        orderType: ManualOrderType.limit,
        quantity: 1,
        price: 1.0,
      ),
    );

    expect(result.accepted, isTrue);
    expect(result.queuedOrders, 1);
    expect(engine.pendingManualOrders, hasLength(1));
    expect(engine.openPosition, isNull);

    wsService.emitKline(3, 0.99);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(engine.pendingManualOrders, isEmpty);
    expect(engine.openPosition, isNotNull);
    expect(engine.openPosition!.isLong, isTrue);
    expect(engine.trades.single.orderType, 'Limit');

    engine.dispose();
    wsService.dispose();
  });

  test('post only rejects an immediately marketable order', () async {
    final wsService = _FakeBinanceWebSocketService();
    final engine = TradingEngine(
      apiService: _FakeBinanceApiService(),
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 0,
        takeProfitPercent: 0,
        tradeQuantity: 1,
      ),
      symbol: 'GALAUSDT',
    );

    final result = await engine.submitManualOrder(
      const ManualOrderRequest(
        action: ManualOrderAction.openLong,
        orderType: ManualOrderType.postOnly,
        quantity: 1,
        price: 1.3,
      ),
    );

    expect(result.accepted, isFalse);
    expect(engine.pendingManualOrders, isEmpty);
    expect(engine.openPosition, isNull);

    engine.dispose();
    wsService.dispose();
  });

  test('scaled order splits into queued child orders', () async {
    final wsService = _FakeBinanceWebSocketService();
    final engine = TradingEngine(
      apiService: _FakeBinanceApiService(),
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 0,
        takeProfitPercent: 0,
        tradeQuantity: 3,
      ),
      symbol: 'GALAUSDT',
    );

    final result = await engine.submitManualOrder(
      const ManualOrderRequest(
        action: ManualOrderAction.openLong,
        orderType: ManualOrderType.scaled,
        quantity: 3,
        price: 1.15,
        scaleEndPrice: 1.05,
        scaleSteps: 3,
      ),
    );

    expect(result.accepted, isTrue);
    expect(result.queuedOrders, 3);
    expect(result.executedOrders, 0);
    expect(engine.pendingManualOrders, hasLength(3));
    expect(engine.pendingManualOrders.first.quantity, 1);

    engine.dispose();
    wsService.dispose();
  });

  test(
    'live Binance sync replaces cached simulated state on startup',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final tradeHistoryService = TradeHistoryService();
      await tradeHistoryService.saveTrades('TRIAUSDT', [
        Trade(
          symbol: 'TRIAUSDT',
          side: 'BUY',
          price: 0.030700,
          quantity: 0.01,
          timestamp: DateTime(2026, 3, 20, 16, 38, 1),
          status: 'simulated',
          strategy: 'AI Analyst',
          kind: 'ENTRY',
        ),
      ]);

      final engine = TradingEngine(
        apiService: _FakeBinanceApiService(
          apiKey: 'live_key',
          apiSecret: 'live_secret',
          positionRiskPayload: [
            {
              'symbol': 'TRIAUSDT',
              'positionAmt': '250',
              'entryPrice': '0.029100',
              'liquidationPrice': '0.021500',
              'updateTime': DateTime(2026, 3, 31, 10, 0).millisecondsSinceEpoch,
            },
          ],
          userTradesPayload: [
            {
              'symbol': 'TRIAUSDT',
              'orderId': '9001',
              'side': 'BUY',
              'price': '0.029100',
              'qty': '250',
              'time': DateTime(2026, 3, 31, 9, 59).millisecondsSinceEpoch,
              'commission': '0.0125',
              'realizedPnl': '0',
              'maker': false,
            },
            {
              'symbol': 'TRIAUSDT',
              'orderId': '9002',
              'side': 'SELL',
              'price': '0.029800',
              'qty': '100',
              'time': DateTime(2026, 3, 31, 10, 1).millisecondsSinceEpoch,
              'commission': '0.0050',
              'realizedPnl': '0.0700',
              'maker': true,
            },
          ],
        ),
        wsService: wsService,
        tradeHistoryService: tradeHistoryService,
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 0,
          takeProfitPercent: 0,
          tradeQuantity: 1,
        ),
        symbol: 'TRIAUSDT',
      );

      await engine.startMarketData();

      expect(engine.openPosition, isNotNull);
      expect(engine.openPosition!.isLong, isTrue);
      expect(engine.openPosition!.quantity, 250);
      expect(engine.openPosition!.entryPrice, 0.0291);
      expect(engine.openPosition!.liquidationPrice, 0.0215);
      expect(engine.trades, hasLength(2));
      expect(engine.trades.first.status, 'filled');
      expect(engine.trades.first.strategy, 'Binance Live');
      expect(engine.trades.first.kind, 'LIVE');
      expect(engine.trades.last.kind, 'EXIT');
      expect(engine.trades.last.realizedPnl, 0.07);
      expect(engine.lastBinanceAccountStatus.state, BinanceAccountState.active);
      expect(
        engine.trades.every((trade) => trade.status != 'simulated'),
        isTrue,
      );

      engine.dispose();
      wsService.dispose();
    },
  );

  test(
    'live Binance sync exposes tracked account fills when selected symbol has none',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final tradeHistoryService = TradeHistoryService();
      final engine = TradingEngine(
        apiService: _FakeBinanceApiService(
          apiKey: 'live_key',
          apiSecret: 'live_secret',
          userTradesBySymbol: {
            'GALAUSDT': const <dynamic>[],
            'TRIAUSDT': [
              {
                'symbol': 'TRIAUSDT',
                'orderId': '9101',
                'side': 'BUY',
                'price': '0.029100',
                'qty': '250',
                'time': DateTime(2026, 3, 31, 9, 59).millisecondsSinceEpoch,
                'commission': '0.0125',
                'realizedPnl': '0',
                'maker': false,
              },
            ],
          },
        ),
        wsService: wsService,
        tradeHistoryService: tradeHistoryService,
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 0,
          takeProfitPercent: 0,
          tradeQuantity: 1,
        ),
        symbol: 'GALAUSDT',
        trackedSymbols: const ['GALAUSDT', 'TRIAUSDT'],
      );

      await engine.startMarketData();

      expect(engine.trades, isEmpty);
      expect(engine.accountTrades, hasLength(1));
      expect(engine.accountTrades.first.symbol, 'TRIAUSDT');
      expect(engine.lastBinanceAccountStatus.state, BinanceAccountState.active);

      final persistedTrackedTrades = await tradeHistoryService.loadTrades(
        'TRIAUSDT',
      );
      expect(persistedTrackedTrades, hasLength(1));

      engine.dispose();
      wsService.dispose();
    },
  );

  test(
    'manual ticket routes live to Binance when account sync is active',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 1,
          takeProfitPercent: 0,
          tradeQuantity: 1,
        ),
        symbol: 'TRIAUSDT',
      );

      final result = await engine.submitManualOrder(
        const ManualOrderRequest(
          action: ManualOrderAction.openLong,
          orderType: ManualOrderType.market,
          quantity: 5,
        ),
      );

      expect(result.accepted, isTrue);
      expect(apiService.placedOrders, isNotEmpty);
      expect(apiService.placedOrders.single['side'], 'BUY');
      expect(engine.trades, isEmpty);
      expect(engine.openPosition, isNull);

      engine.dispose();
      wsService.dispose();
    },
  );

  test(
    'live manual orders explain Binance minimum notional when quantity is too small',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 1,
          takeProfitPercent: 0,
          tradeQuantity: 1,
        ),
        symbol: 'TRIAUSDT',
      );

      final result = await engine.submitManualOrder(
        const ManualOrderRequest(
          action: ManualOrderAction.openLong,
          orderType: ManualOrderType.market,
          quantity: 1,
        ),
      );

      expect(result.accepted, isFalse);
      expect(result.message, contains('minimum tradable size'));
      expect(apiService.placedOrders, isEmpty);

      engine.dispose();
      wsService.dispose();
    },
  );

  test(
    'persisted losing exits restore the protection lock on startup',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final tradeHistoryService = TradeHistoryService();
      await tradeHistoryService.saveTrades('GALAUSDT', [
        Trade(
          symbol: 'GALAUSDT',
          side: 'SELL',
          price: 1.0,
          quantity: 1,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          status: 'simulated',
          strategy: 'Always Buy',
          kind: 'EXIT',
          realizedPnl: -0.2,
          reason: 'stop_loss',
        ),
      ]);

      final engine = TradingEngine(
        apiService: _FakeBinanceApiService(),
        wsService: wsService,
        tradeHistoryService: tradeHistoryService,
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 0,
          takeProfitPercent: 0,
          tradeQuantity: 1,
          protectionPauseMinutes: 30,
          maxConsecutiveLosses: 1,
        ),
        symbol: 'GALAUSDT',
      );

      await engine.startMarketData();

      expect(engine.trades, hasLength(1));
      expect(engine.lastProtectionStatus.state, ProtectionState.locked);
      expect(engine.lastProtectionStatus.message, contains('Loss streak lock'));

      engine.dispose();
      wsService.dispose();
    },
  );

  test('cooldown blocks auto re-entry after a stop loss', () async {
    final wsService = _FakeBinanceWebSocketService();
    final engine = TradingEngine(
      apiService: _FakeBinanceApiService(),
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: _AlwaysBuyStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 5,
        takeProfitPercent: 0,
        tradeQuantity: 1,
        cooldownMinutes: 30,
      ),
      symbol: 'GALAUSDT',
    );

    await engine.enableTrading();
    expect(engine.openPosition, isNotNull);

    wsService.emitKline(3, 1.0);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(engine.openPosition, isNull);
    expect(engine.trades, hasLength(2));
    expect(engine.trades.last.reason, 'stop_loss');
    expect(engine.lastProtectionStatus.state, ProtectionState.cooldown);
    expect(engine.lastProtectionStatus.message, contains('Cooldown active'));

    engine.dispose();
    wsService.dispose();
  });

  test(
    'loss streak lock blocks auto entries after the configured loss count',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final engine = TradingEngine(
        apiService: _FakeBinanceApiService(),
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: _AlwaysBuyStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 5,
          takeProfitPercent: 0,
          tradeQuantity: 1,
          cooldownMinutes: 0,
          protectionPauseMinutes: 45,
          maxConsecutiveLosses: 1,
        ),
        symbol: 'GALAUSDT',
      );

      await engine.enableTrading();
      wsService.emitKline(3, 1.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(engine.openPosition, isNull);
      expect(engine.trades, hasLength(2));
      expect(engine.lastProtectionStatus.state, ProtectionState.locked);
      expect(engine.lastProtectionStatus.message, contains('Loss streak lock'));

      engine.dispose();
      wsService.dispose();
    },
  );

  test(
    'drawdown lock blocks auto entries after realized equity falls from a profitable peak',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final engine = TradingEngine(
        apiService: _FakeBinanceApiService(),
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: _AlwaysBuyStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 5,
          takeProfitPercent: 5,
          tradeQuantity: 1,
          cooldownMinutes: 0,
          protectionPauseMinutes: 45,
          maxDrawdownPercent: 10,
        ),
        symbol: 'GALAUSDT',
      );

      await engine.enableTrading();
      expect(engine.openPosition, isNotNull);

      wsService.emitKline(3, 1.3);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(engine.openPosition, isNotNull);
      expect(engine.trades, hasLength(3));

      wsService.emitKline(4, 1.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(engine.openPosition, isNull);
      expect(engine.trades, hasLength(4));
      expect(engine.lastProtectionStatus.state, ProtectionState.locked);
      expect(
        engine.lastProtectionStatus.message,
        contains('Risk-budget drawdown lock'),
      );

      engine.dispose();
      wsService.dispose();
    },
  );

  test('all-loss history triggers risk-budget drawdown protection', () async {
    final wsService = _FakeBinanceWebSocketService();
    final tradeHistoryService = TradeHistoryService();
    await tradeHistoryService.saveTrades('GALAUSDT', <Trade>[
      Trade(
        symbol: 'GALAUSDT',
        side: 'SELL',
        price: 100,
        quantity: 1,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        status: 'simulated',
        strategy: 'Manual',
        kind: 'EXIT',
        realizedPnl: -12,
      ),
    ]);
    final engine = TradingEngine(
      apiService: _FakeBinanceApiService(),
      wsService: wsService,
      tradeHistoryService: tradeHistoryService,
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 1,
        tradeQuantity: 1,
        investmentUsdt: 100,
        protectionPauseMinutes: 30,
        maxDrawdownPercent: 10,
      ),
      symbol: 'GALAUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.startMarketData();

    expect(engine.lastProtectionStatus.state, ProtectionState.locked);
    expect(engine.lastProtectionStatus.message, contains('12.0%'));
    expect(engine.lastProtectionStatus.message, contains('100.00 USDT'));
  });

  test('fees trigger risk-budget drawdown at the exact boundary', () async {
    final wsService = _FakeBinanceWebSocketService();
    final tradeHistoryService = TradeHistoryService();
    await tradeHistoryService.saveTrades('GALAUSDT', <Trade>[
      Trade(
        symbol: 'GALAUSDT',
        side: 'SELL',
        price: 100,
        quantity: 1,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        status: 'filled',
        strategy: 'Manual',
        kind: 'EXIT',
        realizedPnl: -9.5,
        fee: 0.5,
      ),
    ]);
    final engine = TradingEngine(
      apiService: _FakeBinanceApiService(),
      wsService: wsService,
      tradeHistoryService: tradeHistoryService,
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 1,
        tradeQuantity: 1,
        investmentUsdt: 100,
        protectionPauseMinutes: 30,
        maxDrawdownPercent: 10,
      ),
      symbol: 'GALAUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.startMarketData();

    expect(engine.lastProtectionStatus.state, ProtectionState.locked);
    expect(engine.lastProtectionStatus.message, contains('10.0%'));
    expect(
      engine.lastProtectionStatus.message,
      contains('Risk-budget drawdown lock'),
    );
  });

  test(
    'manual override can still place a trade while protection cooldown is active',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final engine = TradingEngine(
        apiService: _FakeBinanceApiService(),
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: _AlwaysBuyStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 5,
          takeProfitPercent: 0,
          tradeQuantity: 1,
          cooldownMinutes: 30,
        ),
        symbol: 'GALAUSDT',
      );

      await engine.enableTrading();
      wsService.emitKline(3, 1.0);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(engine.lastProtectionStatus.state, ProtectionState.cooldown);
      expect(engine.openPosition, isNull);

      await engine.manualEnterLong();

      expect(engine.isTradingEnabled, isFalse);
      expect(engine.isManualOverrideActive, isTrue);
      expect(engine.openPosition, isNotNull);
      expect(engine.openPosition!.isLong, isTrue);
      expect(engine.trades, hasLength(3));
      expect(engine.trades.last.reason, 'manual');

      engine.dispose();
      wsService.dispose();
    },
  );

  test('auto trading honors plan-defined take profit levels', () async {
    final wsService = _FakeBinanceWebSocketService();
    final engine = TradingEngine(
      apiService: _FakeBinanceApiService(),
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: _PlannedTakeProfitBuyStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 0,
        takeProfitPercent: 0,
        tradeQuantity: 1,
        cooldownMinutes: 30,
      ),
      symbol: 'TRUUSDT',
    );

    await engine.enableTrading();
    expect(engine.openPosition, isNotNull);

    wsService.emitKline(3, 1.26);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(engine.trades.any((trade) => trade.reason == 'take_profit'), isTrue);
    expect(engine.lastProtectionStatus.state, ProtectionState.cooldown);
    expect(engine.openPosition, isNull);

    engine.dispose();
    wsService.dispose();
  });

  test(
    'ambiguous entry quarantines both manual and auto resubmission',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
        unknownOrderSubmissionsRemaining: 1,
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: _AlwaysBuyStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 1,
          takeProfitPercent: 1,
          tradeQuantity: 4.17,
          leverage: 2,
        ),
        symbol: 'TRUUSDT',
      );
      addTearDown(() {
        engine.dispose();
        wsService.dispose();
      });

      await engine.startMarketData();
      final request = ManualOrderRequest(
        action: ManualOrderAction.openLong,
        orderType: ManualOrderType.market,
        quantity: 4.17,
      );
      final uncertain = await engine.submitManualOrder(request);
      final duplicateManual = await engine.submitManualOrder(request);
      await engine.enableTrading();
      await engine.refreshStrategyPlan();

      expect(uncertain.accepted, isFalse);
      expect(duplicateManual.accepted, isFalse);
      expect(duplicateManual.message, contains('working or unresolved'));
      expect(apiService.placedOrders, hasLength(1));
      expect(apiService.orderLookupRequests, greaterThanOrEqualTo(4));
    },
  );

  test('repeated not-found reconciliation clears entry quarantine', () async {
    final wsService = _FakeBinanceWebSocketService();
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
      unknownOrderSubmissionsRemaining: 1,
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 1,
        tradeQuantity: 4.17,
        leverage: 2,
      ),
      symbol: 'TRUUSDT',
      ambiguousEntryMinimumQuarantine: Duration.zero,
      ambiguousEntryNotFoundConfirmations: 1,
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.startMarketData();
    final request = ManualOrderRequest(
      action: ManualOrderAction.openLong,
      orderType: ManualOrderType.market,
      quantity: 4.17,
    );
    final uncertain = await engine.submitManualOrder(request);
    final confirmedAbsentRetry = await engine.submitManualOrder(request);

    expect(uncertain.accepted, isFalse);
    expect(confirmedAbsentRetry.accepted, isTrue);
    expect(apiService.placedOrders, hasLength(2));
  });

  test('known live entry stays tracked until STOP cancels it', () async {
    final wsService = _FakeBinanceWebSocketService();
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 1,
        tradeQuantity: 4.17,
      ),
      symbol: 'TRUUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.startMarketData();
    const request = ManualOrderRequest(
      action: ManualOrderAction.openLong,
      orderType: ManualOrderType.limit,
      quantity: 5.1,
      price: 1,
    );
    final first = await engine.submitManualOrder(request);
    final duplicate = await engine.submitManualOrder(request);

    expect(first.accepted, isTrue);
    expect(duplicate.accepted, isFalse);
    expect(apiService.placedOrders, hasLength(1));

    await engine.disarmTrading(reason: 'test_stop');

    expect(apiService.cancelledOrders.single['orderId'], 'fake-1');
  });

  test('routing expectation blocks paper-demo-live transitions', () async {
    final wsService = _FakeBinanceWebSocketService();
    final apiService = _FakeBinanceApiService(
      apiKey: 'demo_key',
      apiSecret: 'demo_secret',
      isTestnet: true,
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 1,
        tradeQuantity: 4.17,
      ),
      symbol: 'TRUUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.startMarketData();
    for (final expectation in <ManualOrderRoutingExpectation>[
      ManualOrderRoutingExpectation.paper,
      ManualOrderRoutingExpectation.binanceLive,
    ]) {
      final result = await engine.submitManualOrder(
        ManualOrderRequest(
          action: ManualOrderAction.openLong,
          orderType: ManualOrderType.market,
          quantity: 4.17,
          routingExpectation: expectation,
        ),
      );
      expect(result.accepted, isFalse);
      expect(result.message, contains('routing changed'));
    }
    expect(apiService.placedOrders, isEmpty);
  });

  test('STOP gates entries that begin during account reconciliation', () async {
    final wsService = _FakeBinanceWebSocketService();
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 1,
        tradeQuantity: 4.17,
      ),
      symbol: 'TRUUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.startMarketData();
    final syncGate = Completer<void>();
    apiService.accountInfoGate = syncGate;
    final stopFuture = engine.disarmTrading(reason: 'test_stop');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final attemptedEntry = await engine.submitManualOrder(
      const ManualOrderRequest(
        action: ManualOrderAction.openLong,
        orderType: ManualOrderType.market,
        quantity: 4.17,
      ),
    );
    syncGate.complete();
    await stopFuture;

    expect(attemptedEntry.accepted, isFalse);
    expect(attemptedEntry.message, contains('STOP is reconciling'));
    expect(apiService.placedOrders, isEmpty);
  });

  test('STOP waits for an in-flight entry and flattens its fill', () async {
    final wsService = _FakeBinanceWebSocketService();
    final livePositions = <dynamic>[];
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
      positionRiskPayload: livePositions,
      accountInfoPayload: <String, dynamic>{
        'totalWalletBalance': '20',
        'availableBalance': '20',
        'positions': livePositions,
      },
      placeOrderDelay: const Duration(milliseconds: 150),
      onPlaceOrder: (order) {
        if (order['type'] != 'MARKET') return;
        if (order['side'] == 'BUY') {
          livePositions
            ..clear()
            ..add(<String, dynamic>{
              'symbol': 'TRUUSDT',
              'positionAmt': '4.17',
              'entryPrice': '1.2000',
              'positionSide': 'BOTH',
              'updateTime': DateTime.now().millisecondsSinceEpoch,
            });
        } else if (order['side'] == 'SELL') {
          livePositions.clear();
        }
      },
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: _AlwaysBuyStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 0,
        tradeQuantity: 4.17,
        leverage: 2,
      ),
      symbol: 'TRUUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    final enableFuture = engine.enableTrading();
    for (
      var attempt = 0;
      attempt < 100 && apiService.placedOrders.isEmpty;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(apiService.placedOrders, isNotEmpty);

    final stopFuture = engine.disarmTrading(reason: 'test_stop');
    await Future.wait<void>([enableFuture, stopFuture]);

    final marketOrders = apiService.placedOrders
        .where((order) => order['type'] == 'MARKET')
        .toList();
    expect(marketOrders, hasLength(2));
    expect(marketOrders.first['side'], 'BUY');
    expect(marketOrders.last['side'], 'SELL');
    expect(marketOrders.last['reduceOnly'], isTrue);
    expect(livePositions, isEmpty);
    expect(engine.openPosition, isNull);
  });

  test(
    'user-data stream retries after a transient listen-key failure',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
        userDataStartFailuresRemaining: 1,
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 1,
          takeProfitPercent: 1,
          tradeQuantity: 4.17,
        ),
        symbol: 'TRUUSDT',
        userDataRetryBaseDelay: const Duration(milliseconds: 5),
        userDataRetryMaxDelay: const Duration(milliseconds: 10),
      );
      addTearDown(() {
        engine.dispose();
        wsService.dispose();
      });

      await engine.startMarketData();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(apiService.userDataStartRequests, greaterThanOrEqualTo(2));
    },
  );

  test('user-data stream retries after a socket error', () async {
    final wsService = _FakeBinanceWebSocketService();
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 1,
        tradeQuantity: 4.17,
      ),
      symbol: 'TRUUSDT',
      userDataRetryBaseDelay: const Duration(milliseconds: 5),
      userDataRetryMaxDelay: const Duration(milliseconds: 10),
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.startMarketData();
    expect(apiService.userDataStartRequests, 1);
    wsService.emitUserDataError(StateError('socket lost'));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(apiService.userDataStartRequests, greaterThanOrEqualTo(2));
  });

  test(
    'another installation cannot claim or cancel scoped entry orders',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
        openOrdersPayload: <dynamic>[
          <String, dynamic>{
            'symbol': 'TRUUSDT',
            'orderId': 'foreign-entry',
            'clientOrderId': 'ifut-entry-owner001-seed-1',
            'side': 'BUY',
            'type': 'LIMIT',
            'price': '1.0000',
            'origQty': '5',
            'reduceOnly': false,
            'closePosition': false,
            'time': DateTime.now().millisecondsSinceEpoch,
          },
        ],
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 1,
          takeProfitPercent: 1,
          tradeQuantity: 4.17,
        ),
        symbol: 'TRUUSDT',
        clientOrderOwnerId: 'owner002',
      );
      addTearDown(() {
        engine.dispose();
        wsService.dispose();
      });

      await engine.startMarketData();

      expect(apiService.cancelledOrders, isEmpty);
      expect(engine.openOrders.single.orderId, 'foreign-entry');
    },
  );

  test('stale owned protection cannot claim a foreign position', () async {
    final wsService = _FakeBinanceWebSocketService();
    final livePositions = <dynamic>[
      <String, dynamic>{
        'symbol': 'TRUUSDT',
        'positionAmt': '4.17',
        'entryPrice': '1.2000',
        'positionSide': 'BOTH',
        'updateTime': DateTime.now().millisecondsSinceEpoch,
      },
    ];
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
      positionRiskPayload: livePositions,
      openAlgoOrdersPayload: <dynamic>[
        <String, dynamic>{
          'symbol': 'TRUUSDT',
          'algoId': 'stale-owned-stop',
          'clientAlgoId': 'ifut-sl-local000-stale-1',
          'side': 'SELL',
          'orderType': 'STOP_MARKET',
          'triggerPrice': '1.1400',
          'quantity': '0',
          'closePosition': true,
          'positionSide': 'BOTH',
          'createTime': DateTime.now().millisecondsSinceEpoch,
        },
      ],
      accountInfoPayload: <String, dynamic>{
        'totalWalletBalance': '20',
        'availableBalance': '20',
        'positions': livePositions,
      },
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: _AlwaysSellStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 5,
        takeProfitPercent: 0,
        tradeQuantity: 4.17,
      ),
      symbol: 'TRUUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.enableTrading();

    expect(engine.openPosition, isNotNull);
    expect(apiService.placedOrders, isEmpty);
    expect(apiService.cancelledAlgoOrders, isEmpty);
  });

  test('unconfirmed stop acknowledgement triggers emergency flatten', () async {
    final wsService = _FakeBinanceWebSocketService();
    final livePositions = <dynamic>[];
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
      positionRiskPayload: livePositions,
      publishPlacedAlgoOrders: false,
      accountInfoPayload: <String, dynamic>{
        'totalWalletBalance': '20',
        'availableBalance': '20',
        'positions': livePositions,
      },
      onPlaceOrder: (order) {
        if (order['type'] != 'MARKET') return;
        if (order['side'] == 'BUY') {
          livePositions
            ..clear()
            ..add(<String, dynamic>{
              'symbol': 'TRUUSDT',
              'positionAmt': '4.17',
              'entryPrice': '1.2000',
              'positionSide': 'BOTH',
              'updateTime': DateTime.now().millisecondsSinceEpoch,
            });
        } else if (order['side'] == 'SELL') {
          livePositions.clear();
        }
      },
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 5,
        takeProfitPercent: 0,
        tradeQuantity: 4.17,
      ),
      symbol: 'TRUUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.startMarketData();
    final result = await engine.submitManualOrder(
      const ManualOrderRequest(
        action: ManualOrderAction.openLong,
        orderType: ManualOrderType.market,
        quantity: 4.17,
      ),
    );

    final marketOrders = apiService.placedOrders
        .where((order) => order['type'] == 'MARKET')
        .toList();
    expect(result.accepted, isFalse);
    expect(marketOrders, hasLength(2));
    expect(marketOrders.last['side'], 'SELL');
    expect(marketOrders.last['reduceOnly'], isTrue);
    expect(livePositions, isEmpty);
  });

  test(
    'partial reduce-only stop is replaced by full close protection',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final livePositions = <dynamic>[];
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
        positionRiskPayload: livePositions,
        accountInfoPayload: <String, dynamic>{
          'totalWalletBalance': '20',
          'availableBalance': '20',
          'positions': livePositions,
        },
        onPlaceOrder: (order) {
          if (order['type'] == 'MARKET' && order['side'] == 'BUY') {
            livePositions
              ..clear()
              ..add(<String, dynamic>{
                'symbol': 'TRUUSDT',
                'positionAmt': '4.17',
                'entryPrice': '1.2000',
                'positionSide': 'BOTH',
                'updateTime': DateTime.now().millisecondsSinceEpoch,
              });
          }
        },
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 5,
          takeProfitPercent: 0,
          tradeQuantity: 4.17,
        ),
        symbol: 'TRUUSDT',
      );
      addTearDown(() {
        engine.dispose();
        wsService.dispose();
      });

      await engine.startMarketData();
      final entry = await engine.submitManualOrder(
        const ManualOrderRequest(
          action: ManualOrderAction.openLong,
          orderType: ManualOrderType.market,
          quantity: 4.17,
        ),
      );
      expect(entry.accepted, isTrue);

      apiService.placedOrders.clear();
      apiService.cancelledAlgoOrders.clear();
      apiService.openAlgoOrdersPayload
        ..clear()
        ..add(<String, dynamic>{
          'symbol': 'TRUUSDT',
          'algoId': 'partial-stop',
          'clientAlgoId': 'ifut-sl-local000-partial-1',
          'side': 'SELL',
          'orderType': 'STOP_MARKET',
          'triggerPrice': '1.1400',
          'quantity': '1',
          'reduceOnly': true,
          'closePosition': false,
          'positionSide': 'BOTH',
          'createTime': DateTime.now().millisecondsSinceEpoch,
        });
      wsService.emitUserDataEvent(<String, dynamic>{'e': 'ACCOUNT_UPDATE'});
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(apiService.placedOrders, hasLength(1));
      expect(apiService.placedOrders.single['type'], 'STOP_MARKET');
      expect(apiService.placedOrders.single['closePosition'], isTrue);
      expect(apiService.cancelledAlgoOrders.single['algoId'], 'partial-stop');
    },
  );

  test('auto strategy never reverses a foreign Binance position', () async {
    final wsService = _FakeBinanceWebSocketService();
    final livePositions = <dynamic>[
      <String, dynamic>{
        'symbol': 'TRUUSDT',
        'positionAmt': '4.17',
        'entryPrice': '1.2000',
        'positionSide': 'BOTH',
        'updateTime': DateTime.now().millisecondsSinceEpoch,
      },
    ];
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
      positionRiskPayload: livePositions,
      accountInfoPayload: <String, dynamic>{
        'totalWalletBalance': '20',
        'availableBalance': '20',
        'positions': livePositions,
      },
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: _AlwaysSellStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 0,
        tradeQuantity: 4.17,
        leverage: 2,
      ),
      symbol: 'TRUUSDT',
    );
    addTearDown(() {
      engine.dispose();
      wsService.dispose();
    });

    await engine.enableTrading();

    expect(apiService.placedOrders, isEmpty);
    expect(engine.openPosition, isNotNull);
    expect(
      engine.consoleEntries.any(
        (entry) => entry.message.contains('not owned by this iFutures'),
      ),
      isTrue,
    );
  });

  test('live Binance positions close through the exchange risk path', () async {
    final wsService = _FakeBinanceWebSocketService();
    final livePositions = <dynamic>[];
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
      positionRiskPayload: livePositions,
      accountInfoPayload: <String, dynamic>{
        'totalWalletBalance': '10',
        'availableBalance': '10',
        'positions': livePositions,
      },
      onPlaceOrder: (order) {
        if (order['type'] != 'MARKET') return;
        if (order['side'] == 'BUY') {
          livePositions
            ..clear()
            ..add(<String, dynamic>{
              'symbol': 'TRUUSDT',
              'positionAmt': '4.17',
              'entryPrice': '1.2000',
              'positionSide': 'BOTH',
              'updateTime': DateTime.now().millisecondsSinceEpoch,
            });
        } else if (order['side'] == 'SELL') {
          livePositions.clear();
        }
      },
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 5,
        takeProfitPercent: 5,
        tradeQuantity: 4.17,
        leverage: 7,
      ),
      symbol: 'TRUUSDT',
    );

    await engine.startMarketData();
    final entry = await engine.submitManualOrder(
      const ManualOrderRequest(
        action: ManualOrderAction.openLong,
        orderType: ManualOrderType.market,
        quantity: 4.17,
      ),
    );
    expect(entry.accepted, isTrue, reason: entry.message);
    expect(engine.openPosition, isNotNull);
    expect(engine.openPosition!.isLong, isTrue);

    wsService.emitKline(3, 1.26);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(apiService.placedOrders.length, greaterThanOrEqualTo(1));
    expect(apiService.placedOrders.last['side'], 'SELL');
    expect(engine.openPosition, isNull);
    expect(
      engine.consoleEntries.any(
        (entry) => entry.message.contains('Sent live take profit close'),
      ),
      isTrue,
    );

    engine.dispose();
    wsService.dispose();
  });

  test(
    'foreign Binance position crossing app TP and SL is never mutated',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final livePositions = <dynamic>[
        <String, dynamic>{
          'symbol': 'TRUUSDT',
          'positionAmt': '4.17',
          'entryPrice': '1.2000',
          'positionSide': 'LONG',
          'updateTime': DateTime(2026, 4, 7, 11, 0).millisecondsSinceEpoch,
        },
      ];
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
        positionRiskPayload: livePositions,
        accountInfoPayload: <String, dynamic>{
          'totalWalletBalance': '10',
          'availableBalance': '10',
          'positions': livePositions,
        },
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 5,
          takeProfitPercent: 5,
          tradeQuantity: 1,
          leverage: 7,
        ),
        symbol: 'TRUUSDT',
      );

      await engine.startMarketData();
      expect(engine.openPosition, isNotNull);

      wsService.emitKline(3, 1.27);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      wsService.emitKline(4, 1.13);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.openPosition, isNotNull);
      expect(apiService.placedOrders, isEmpty);
      expect(apiService.cancelledOrders, isEmpty);
      expect(apiService.cancelledAlgoOrders, isEmpty);
      expect(apiService.leverageUpdates, isEmpty);

      engine.dispose();
      wsService.dispose();
    },
  );

  test(
    'owned live entry places exchange-confirmed TP and SL protection',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final livePositions = <dynamic>[];
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
        positionRiskPayload: livePositions,
        accountInfoPayload: <String, dynamic>{
          'totalWalletBalance': '10',
          'availableBalance': '10',
          'positions': livePositions,
        },
        onPlaceOrder: (order) {
          if (order['type'] == 'MARKET' && order['side'] == 'BUY') {
            livePositions
              ..clear()
              ..add(<String, dynamic>{
                'symbol': 'TRUUSDT',
                'positionAmt': '4.17',
                'entryPrice': '1.2000',
                'positionSide': 'BOTH',
                'updateTime': DateTime.now().millisecondsSinceEpoch,
              });
          }
        },
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: ManualStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 1,
          takeProfitPercent: 1,
          tradeQuantity: 4.17,
          leverage: 4,
        ),
        symbol: 'TRUUSDT',
      );

      await engine.startMarketData();
      final entry = await engine.submitManualOrder(
        const ManualOrderRequest(
          action: ManualOrderAction.openLong,
          orderType: ManualOrderType.market,
          quantity: 4.17,
        ),
      );
      expect(entry.accepted, isTrue);

      expect(
        apiService.placedOrders.any(
          (order) => order['type'] == 'TAKE_PROFIT_MARKET',
        ),
        isTrue,
      );
      expect(
        apiService.placedOrders.any((order) => order['type'] == 'STOP_MARKET'),
        isTrue,
      );
      expect(
        engine.openOrders.any(
          (order) => order.type == 'TAKE_PROFIT_MARKET' && order.closePosition,
        ),
        isTrue,
      );
      expect(
        engine.openOrders.any(
          (order) => order.type == 'STOP_MARKET' && order.closePosition,
        ),
        isTrue,
      );

      engine.dispose();
      wsService.dispose();
    },
  );

  test(
    'auto trading submits live Binance orders when account sync is active',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
        accountInfoPayload: const <String, dynamic>{
          'totalWalletBalance': '10',
          'availableBalance': '10',
          'positions': <dynamic>[],
        },
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: _PlannedTakeProfitBuyStrategy(),
        riskSettings: const RiskSettings(
          stopLossPercent: 1,
          takeProfitPercent: 0,
          tradeQuantity: 1,
          leverage: 7,
        ),
        symbol: 'TRUUSDT',
      );

      await engine.enableTrading();

      expect(apiService.leverageUpdates, isNotEmpty);
      expect(apiService.leverageUpdates.single['leverage'], 7);
      expect(apiService.placedOrders, isNotEmpty);
      expect(apiService.placedOrders.single['symbol'], 'TRUUSDT');
      expect(apiService.placedOrders.single['side'], 'BUY');
      expect(apiService.placedOrders.single['type'], 'MARKET');
      expect(apiService.placedOrders.single['quantity'], '4.17');
      expect(apiService.placedOrders.single['positionSide'], isNull);
      expect(apiService.placedOrders.single['reduceOnly'], isNull);
      expect(apiService.positionModeRequests, greaterThan(0));
      expect(
        engine.consoleEntries.any(
          (entry) => entry.message.contains('Raised auto size'),
        ),
        isTrue,
      );
      expect(
        engine.consoleEntries.any(
          (entry) => entry.message.contains('sent market long'),
        ),
        isTrue,
      );

      engine.dispose();
      wsService.dispose();
    },
  );

  test(
    'auto entry validates liquidation distance with plan leverage',
    () async {
      final wsService = _FakeBinanceWebSocketService();
      final apiService = _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
        accountInfoPayload: const <String, dynamic>{
          'totalWalletBalance': '10',
          'availableBalance': '10',
          'positions': <dynamic>[],
        },
      );
      final engine = TradingEngine(
        apiService: apiService,
        wsService: wsService,
        tradeHistoryService: TradeHistoryService(),
        strategy: _LeveragedBuyStrategy(
          planLeverage: 50,
          planStopLossPercent: 5,
        ),
        riskSettings: const RiskSettings(
          stopLossPercent: 5,
          takeProfitPercent: 1,
          tradeQuantity: 4.17,
          leverage: 10,
        ),
        symbol: 'TRUUSDT',
      );
      addTearDown(() {
        engine.dispose();
        wsService.dispose();
      });

      await engine.enableTrading();

      expect(apiService.placedOrders, isEmpty);
      expect(
        engine.consoleEntries.any(
          (entry) =>
              entry.message.contains('estimated liquidation zone at 50x'),
        ),
        isTrue,
      );
    },
  );

  test('live Binance orders are blocked in hedge mode', () async {
    final wsService = _FakeBinanceWebSocketService();
    final apiService = _FakeBinanceApiService(
      apiKey: 'live_key',
      apiSecret: 'live_secret',
      positionMode: BinanceFuturesPositionMode.hedge,
      accountInfoPayload: const <String, dynamic>{
        'totalWalletBalance': '10',
        'availableBalance': '10',
        'positions': <dynamic>[],
      },
    );
    final engine = TradingEngine(
      apiService: apiService,
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: _PlannedTakeProfitBuyStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 0,
        tradeQuantity: 1,
        leverage: 7,
      ),
      symbol: 'TRUUSDT',
    );

    await engine.enableTrading();

    expect(apiService.placedOrders, isEmpty);
    expect(
      engine.consoleEntries.any(
        (entry) => entry.message.contains('blocked in Hedge Mode'),
      ),
      isTrue,
    );

    engine.dispose();
    wsService.dispose();
  });
}
