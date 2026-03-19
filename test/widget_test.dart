import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ifutures/constants/symbols.dart';
import 'package:ifutures/models/connection_status.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/main.dart';
import 'package:ifutures/providers/trading_provider.dart';
import 'package:ifutures/screens/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('iFutures boots into the dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsInitProvider.overrideWith((ref) async {}),
          symbolListProvider.overrideWith((ref) async => [defaultSymbol]),
          riskSettingsProvider.overrideWith(
            (ref) async => const RiskSettings(
              stopLossPercent: 1.0,
              takeProfitPercent: 2.0,
              tradeQuantity: 0.01,
            ),
          ),
          tickerStreamProvider.overrideWith((ref, symbol) async* {
            yield {'c': '0.00335'};
          }),
          tradeStreamProvider.overrideWith((ref, symbol) async* {
            yield const <Trade>[];
          }),
          positionStreamProvider.overrideWith((ref, symbol) async* {
            yield null;
          }),
          signalStreamProvider.overrideWith((ref, symbol) async* {
            yield null;
          }),
          connectionStatusProvider.overrideWith((ref, symbol) async* {
            yield ConnectionStatus.disconnected();
          }),
          priceAlertsProvider.overrideWith((ref, symbol) async => const []),
        ],
        child: const IFuturesApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('iFutures'), findsOneWidget);
    expect(find.text('Price Action'), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'iFutures Bot');
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
  });
}
