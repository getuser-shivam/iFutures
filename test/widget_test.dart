import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ifutures/constants/symbols.dart';
import 'package:ifutures/models/binance_account_status.dart';
import 'package:ifutures/models/connection_status.dart';
import 'package:ifutures/models/manual_order.dart';
import 'package:ifutures/models/market_analysis.dart';
import 'package:ifutures/models/position.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/models/ai_service_status.dart';
import 'package:ifutures/models/strategy_console_entry.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/main.dart';
import 'package:ifutures/providers/trading_provider.dart';
import 'package:ifutures/screens/dashboard_screen.dart';
import 'package:ifutures/trading/strategy.dart';

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
          accountTradeStreamProvider.overrideWith((ref, symbol) async* {
            yield [
              Trade(
                symbol: 'TRIAUSDT',
                side: 'BUY',
                price: 0.0032,
                quantity: 900,
                timestamp: DateTime(2026, 3, 20, 11, 40),
                status: 'filled',
                strategy: 'Binance Live',
                kind: 'LIVE',
              ),
            ];
          }),
          positionStreamProvider.overrideWith((ref, symbol) async* {
            yield Position(
              symbol: symbol,
              side: PositionSide.short,
              entryPrice: 0.00348,
              quantity: 1200,
              entryTime: DateTime(2026, 3, 20, 11, 55),
            );
          }),
          pendingManualOrderStreamProvider.overrideWith((ref, symbol) async* {
            yield const <PendingManualOrder>[];
          }),
          signalStreamProvider.overrideWith((ref, symbol) async* {
            yield null;
          }),
          decisionPlanStreamProvider.overrideWith((ref, symbol) async* {
            yield StrategyTradePlan(
              strategyName: 'AI Analyst',
              signal: TradingSignal.sell,
              orderType: ManualOrderType.postOnly,
              currentPrice: 0.00335,
              targetEntryPrice: 0.0035,
              leverage: 20,
              takeProfitPercent: 35,
              stopLossPercent: 20,
              quantity: 1200,
              rationale:
                  'AI sees price near the configured short zone and prefers passive post-only execution until momentum confirms.',
              generatedAt: DateTime(2026, 3, 20, 12, 5),
              confidence: 0.82,
              longBiasPrice: 0.003,
              shortBiasPrice: 0.0035,
            );
          }),
          consoleLogStreamProvider.overrideWith((ref, symbol) async* {
            yield [
              StrategyConsoleEntry(
                timestamp: DateTime(2026, 3, 20, 12, 4),
                level: StrategyConsoleLevel.info,
                message: 'Loaded 100 historical candles for TRIAUSDT.',
              ),
              StrategyConsoleEntry(
                timestamp: DateTime(2026, 3, 20, 12, 5),
                level: StrategyConsoleLevel.warning,
                message:
                    'AI Analyst: SHORT | Post Only at 0.003500. TP 35.00% | SL 20.00% | 20x.',
              ),
            ];
          }),
          connectionStatusProvider.overrideWith((ref, symbol) async* {
            yield ConnectionStatus.disconnected();
          }),
          binanceAccountStatusProvider.overrideWith((ref, symbol) async* {
            yield BinanceAccountStatus.active(
              isTestnet: true,
              lastSyncedAt: DateTime(2026, 3, 20, 12, 1),
              message: 'Binance testnet account sync is active.',
            );
          }),
          aiServiceStatusProvider.overrideWith((ref, symbol) async {
            return AiServiceStatus.active(
              providerLabel: 'Groq Chat',
              checkedAt: DateTime(2026, 3, 20, 12, 2),
              message: 'Groq Chat accepted the last AI connectivity check.',
            );
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
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'iFutures Bot');
    expect(materialApp.debugShowCheckedModeBanner, isFalse);

    expect(find.text('Strategy Workspace'), findsOneWidget);
    expect(find.text('USDT'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(
      find.textContaining(
        'Mode selection, manual tickets, and backtesting now live in Settings',
      ),
      findsOneWidget,
    );
    expect(find.text('Strategy Terminal'), findsOneWidget);
    expect(find.text('Manual Order Ticket'), findsNothing);
    expect(find.text('Binance: Active'), findsOneWidget);
  });
}
