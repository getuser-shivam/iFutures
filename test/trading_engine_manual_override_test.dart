import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/binance_account_status.dart';
import 'package:ifutures/models/connection_status.dart';
import 'package:ifutures/models/manual_order.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/services/binance_api.dart';
import 'package:ifutures/services/binance_ws.dart';
import 'package:ifutures/services/trade_history_service.dart';
import 'package:ifutures/trading/manual_strategy.dart';
import 'package:ifutures/trading/trading_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBinanceApiService extends BinanceApiService {
  final List<dynamic> positionRiskPayload;
  final List<dynamic> userTradesPayload;

  _FakeBinanceApiService({
    String apiKey = '',
    String apiSecret = '',
    this.positionRiskPayload = const <dynamic>[],
    this.userTradesPayload = const <dynamic>[],
  }) : super(apiKey: apiKey, apiSecret: apiSecret);

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
  Future<List<dynamic>> getUserTrades({
    required String symbol,
    int limit = 100,
  }) async {
    return userTradesPayload;
  }
}

class _FakeBinanceWebSocketService extends BinanceWebSocketService {
  final _controller = StreamController<dynamic>.broadcast();

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

  test('manual ticket is rejected in read-only Binance sync mode', () async {
    final wsService = _FakeBinanceWebSocketService();
    final engine = TradingEngine(
      apiService: _FakeBinanceApiService(
        apiKey: 'live_key',
        apiSecret: 'live_secret',
      ),
      wsService: wsService,
      tradeHistoryService: TradeHistoryService(),
      strategy: ManualStrategy(),
      riskSettings: const RiskSettings(
        stopLossPercent: 0,
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
    expect(engine.trades, isEmpty);
    expect(engine.openPosition, isNull);

    engine.dispose();
    wsService.dispose();
  });
}
