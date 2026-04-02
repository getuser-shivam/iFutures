import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ifutures/constants/symbols.dart';
import 'package:ifutures/models/manual_order.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/providers/trading_provider.dart';
import 'package:ifutures/trading/strategy.dart';
import 'package:ifutures/widgets/dashboard/manual_order_ticket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('manual ticket can preload the latest AI plan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsInitProvider.overrideWith((ref) async {}),
          riskSettingsProvider.overrideWith(
            (ref) async => const RiskSettings(
              stopLossPercent: 2.0,
              takeProfitPercent: 4.0,
              tradeQuantity: 0.01,
            ),
          ),
          tradingEngineProvider.overrideWith(
            (ref, symbol) => Completer<Never>().future,
          ),
          tickerStreamProvider.overrideWith((ref, symbol) async* {
            yield {'c': '0.00310'};
          }),
          positionStreamProvider.overrideWith((ref, symbol) async* {
            yield null;
          }),
          pendingManualOrderStreamProvider.overrideWith((ref, symbol) async* {
            yield const <PendingManualOrder>[];
          }),
          signalStreamProvider.overrideWith((ref, symbol) async* {
            yield TradingSignal.hold;
          }),
          decisionPlanStreamProvider.overrideWith((ref, symbol) async* {
            yield StrategyTradePlan(
              strategyName: 'AI Analyst',
              signal: TradingSignal.sell,
              orderType: ManualOrderType.postOnly,
              currentPrice: 0.00310,
              targetEntryPrice: 0.00318,
              leverage: 10,
              takeProfitPercent: 5,
              stopLossPercent: 2,
              quantity: 12.3456,
              rationale:
                  'Recent ask pressure and weak outcome memory keep the plan patient.',
              generatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
              confidence: 0.78,
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManualOrderTicket(symbol: defaultSymbol),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Latest AI Analyst Plan'), findsOneWidget);
    expect(find.text('USE LATEST PLAN'), findsOneWidget);
    expect(find.text('MARKET OPEN LONG'), findsOneWidget);

    await tester.tap(find.text('USE LATEST PLAN'));
    await tester.pump();

    expect(find.text('POST ONLY OPEN SHORT'), findsOneWidget);
    expect(
      find.text('Loaded AI Analyst plan into the manual ticket.'),
      findsOneWidget,
    );
  });
}
