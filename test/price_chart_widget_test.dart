import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ifutures/models/connection_status.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/models/live_order.dart';
import 'package:ifutures/models/manual_order.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/providers/trading_provider.dart';
import 'package:ifutures/trading/strategy.dart';
import 'package:ifutures/widgets/dashboard/price_chart.dart';

void main() {
  const symbol = 'ARIAUSDT';
  const ownerId = 'owner001';

  List<Kline> candles() {
    final start = DateTime.utc(2026, 7, 14, 8);
    return List<Kline>.generate(48, (index) {
      final open = 100 + (index * 0.02);
      final close = open + (index.isEven ? 0.15 : -0.1);
      final openTime = start.add(Duration(minutes: index * 5));
      return Kline(
        openTime: openTime,
        open: open,
        high: open + 0.4,
        low: open - 0.4,
        close: close,
        volume: 1000 + index.toDouble(),
        closeTime: openTime.add(const Duration(minutes: 5)),
      );
    });
  }

  StrategyTradePlan distantPlan() => StrategyTradePlan(
    strategyName: 'RSI Strategy',
    signal: TradingSignal.buy,
    orderType: ManualOrderType.limit,
    currentPrice: 100,
    targetEntryPrice: 1000,
    leverage: 10,
    takeProfitPercent: 10,
    stopLossPercent: 10,
    rationale: 'Widget fixture',
    generatedAt: DateTime.utc(2026, 7, 14, 9),
  );

  Widget subject({required Size size}) {
    return ProviderScope(
      overrides: [
        tradingClientOwnerIdProvider.overrideWith((ref) async => ownerId),
        klineStreamProvider.overrideWith((ref, requestedSymbol) async* {
          yield candles();
        }),
        decisionPlanStreamProvider.overrideWith((ref, requestedSymbol) async* {
          yield distantPlan();
        }),
        positionStreamProvider.overrideWith((ref, requestedSymbol) async* {
          yield null;
        }),
        tradeStreamProvider.overrideWith((ref, requestedSymbol) async* {
          yield const <Trade>[];
        }),
        connectionStatusProvider.overrideWith((ref, requestedSymbol) async* {
          yield ConnectionStatus.disconnected();
        }),
        openOrderStreamProvider.overrideWith((ref, requestedSymbol) async* {
          yield [
            LiveOrder(
              symbol: symbol,
              orderId: '42',
              clientOrderId: 'ifut-stop-$ownerId-seed-1',
              side: 'SELL',
              type: 'STOP_MARKET',
              price: 0,
              stopPrice: 100.25,
              quantity: 1,
              reduceOnly: true,
              closePosition: true,
              updatedAt: DateTime.utc(2026, 7, 14, 9),
            ),
          ];
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: const PriceChart(symbol: symbol),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'narrow chart stays laid out and reports disconnected market truthfully',
    (tester) async {
      await tester.pumpWidget(subject(size: const Size(360, 1050)));
      await tester.pumpAndSettle();

      expect(find.text('Market disconnected'), findsOneWidget);
      expect(find.textContaining('Realtime'), findsNothing);
      expect(find.textContaining('AI '), findsNothing);
      expect(find.textContaining('PLAN ENTRY'), findsWidgets);
      expect(find.textContaining('off chart'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('risk levels do not expand candle domain and zoom is disabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject(size: const Size(1000, 620)));
    await tester.pumpAndSettle();

    final chart = tester.widget<CandlestickChart>(
      find.byType(CandlestickChart),
    );
    expect(chart.data.minY, greaterThan(90));
    expect(chart.data.maxY, lessThan(110));
    expect(chart.data.minX, -0.6);
    expect(chart.data.maxX, 47.6);
    expect(chart.transformationConfig.scaleAxis, FlScaleAxis.none);
    expect(find.text('EXCH SL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
