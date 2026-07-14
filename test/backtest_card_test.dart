import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/constants/symbols.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/providers/trading_provider.dart';
import 'package:ifutures/services/binance_api.dart';
import 'package:ifutures/widgets/dashboard/backtest_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('mock lab stays usable on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_testApp(api: _HistoricalApi()));
    await tester.pumpAndSettle();

    expect(find.text('Multi-Coin Mock Lab'), findsOneWidget);
    for (final symbol in coreTradingSymbols) {
      expect(find.text(symbol), findsOneWidget);
    }
    expect(find.text('RUN MULTI-COIN MOCK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one click replays every selected core coin', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _HistoricalApi();

    await tester.pumpWidget(_testApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RUN MULTI-COIN MOCK'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(api.requestedSymbols.toSet(), coreTradingSymbols.toSet());
    expect(find.text('Per-coin contribution'), findsOneWidget);
    expect(find.text('Portfolio mock equity (mark-to-market)'), findsOneWidget);
    expect(
      find.textContaining('does not establish future or live profitability'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({required BinanceApiService api}) {
  return ProviderScope(
    overrides: [
      historicalBinanceApiProvider.overrideWithValue(api),
      riskSettingsProvider.overrideWith(
        (ref) async => const RiskSettings(
          stopLossPercent: 3,
          takeProfitPercent: 5,
          tradeQuantity: 1,
          investmentUsdt: 100,
          leverage: 1,
        ),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: BacktestCard(symbol: defaultSymbol),
        ),
      ),
    ),
  );
}

class _HistoricalApi extends BinanceApiService {
  static final int _serverTime = DateTime.utc(
    2026,
    7,
    14,
    12,
  ).millisecondsSinceEpoch;

  final List<String> requestedSymbols = [];

  _HistoricalApi()
    : super(
        apiKey: '',
        apiSecret: '',
        isTestnet: false,
        allowOrderMutations: false,
      );

  @override
  Future<int> getServerTime({
    BinanceApiScope scope = BinanceApiScope.futures,
  }) async {
    return _serverTime;
  }

  @override
  Future<List<dynamic>> getKlines({
    required String symbol,
    String interval = '1m',
    int? limit,
    int? startTime,
    int? endTime,
  }) async {
    requestedSymbols.add(symbol);
    final symbolOffset = coreTradingSymbols.indexOf(symbol).clamp(0, 3) * 3.0;
    final start = _serverTime - const Duration(hours: 10).inMilliseconds;
    return List<List<dynamic>>.generate(120, (index) {
      final openTime = start + Duration(minutes: index * 5).inMilliseconds;
      final closeTime =
          openTime + const Duration(minutes: 5).inMilliseconds - 1;
      final center = 100 + symbolOffset + (math.sin(index / 4) * 9);
      final next = 100 + symbolOffset + (math.sin((index + 1) / 4) * 9);
      final high = math.max(center, next) + 1;
      final low = math.min(center, next) - 1;
      return [
        openTime,
        center.toString(),
        high.toString(),
        low.toString(),
        next.toString(),
        '1000',
        closeTime,
      ];
    });
  }

  @override
  Future<List<dynamic>> getFundingRateHistory({
    required String symbol,
    int? startTime,
    int? endTime,
    int limit = 1000,
  }) async {
    return const [];
  }
}
