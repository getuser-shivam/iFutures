import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/connection_status.dart';
import 'package:ifutures/models/manual_order.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/services/binance_api.dart';
import 'package:ifutures/services/binance_ws.dart';
import 'package:ifutures/services/trade_history_service.dart';
import 'package:ifutures/trading/manual_strategy.dart';
import 'package:ifutures/trading/trading_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBinanceApiService extends BinanceApiService {
  _FakeBinanceApiService() : super(apiKey: '', apiSecret: '');

  @override
  Future<List<dynamic>> getKlines({
    required String symbol,
    String interval = '1m',
    int? limit,
  }) async {
    return [_klineJson(0, 1.0), _klineJson(1, 1.1), _klineJson(2, 1.2)];
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
}
