import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ifutures/constants/symbols.dart';
import 'package:ifutures/models/connection_status.dart';
import 'package:ifutures/models/market_analysis.dart';
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

  testWidgets('iFutures boots into the dashboard shell', (
    WidgetTester tester,
  ) async {
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
          marketAnalysisProvider.overrideWith((ref) async {
            return MarketAnalysisSnapshot(
              updatedAt: DateTime(2026, 3, 20, 12, 0),
              assets: [
                MarketAssetSnapshot(
                  symbol: 'BTCUSDT',
                  displayName: 'BTC',
                  lastPrice: 70606.12,
                  changePercent: 1.24,
                  highPrice: 71200,
                  lowPrice: 69910,
                  volume: 123456.78,
                  updatedAt: DateTime(2026, 3, 20, 12, 0),
                ),
                MarketAssetSnapshot(
                  symbol: 'ETHUSDT',
                  displayName: 'ETH',
                  lastPrice: 2140.73,
                  changePercent: -0.42,
                  highPrice: 2180,
                  lowPrice: 2122,
                  volume: 98765.43,
                  updatedAt: DateTime(2026, 3, 20, 12, 0),
                ),
                MarketAssetSnapshot(
                  symbol: 'BNBUSDT',
                  displayName: 'BNB',
                  lastPrice: 642.85,
                  changePercent: 0.38,
                  highPrice: 651,
                  lowPrice: 635,
                  volume: 45678.9,
                  updatedAt: DateTime(2026, 3, 20, 12, 0),
                ),
                MarketAssetSnapshot(
                  symbol: 'SOLUSDT',
                  displayName: 'SOL',
                  lastPrice: 89.31,
                  changePercent: -1.12,
                  highPrice: 92,
                  lowPrice: 88,
                  volume: 56789.01,
                  updatedAt: DateTime(2026, 3, 20, 12, 0),
                ),
              ],
              news: const [
                MarketNewsItem(
                  source: 'CryptoControl',
                  feedLabel: 'BTC',
                  title: 'Bitcoin flow remains resilient in new fund data',
                  summary:
                      'BTC-heavy inflows support broader market sentiment.',
                  link: 'https://example.com/btc',
                ),
                MarketNewsItem(
                  source: 'CryptoControl',
                  feedLabel: 'ETH',
                  title: 'Ethereum staking products keep attracting attention',
                  summary:
                      'ETH headlines remain constructive for medium-term momentum.',
                  link: 'https://example.com/eth',
                ),
              ],
              bias: MarketBias.neutral,
              summary:
                  'BTC is leading the tape while ETH is mixed. The latest pulse is driven by BTC and ETH crypto headlines.',
              shortWatch:
                  'Short watch: the tape is mixed, so wait for a clear rejection or loss of support before shorting.',
            );
          }),
        ],
        child: const IFuturesApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('iFutures'), findsOneWidget);
    expect(find.text('Market Analysis'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Manual Controls'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'iFutures Bot');
    expect(materialApp.debugShowCheckedModeBanner, isFalse);

    expect(find.text('Manual Controls'), findsOneWidget);
    expect(find.text('LONG'), findsOneWidget);
    expect(find.text('SHORT'), findsOneWidget);
    expect(find.text('CLOSE'), findsOneWidget);
  });
}
