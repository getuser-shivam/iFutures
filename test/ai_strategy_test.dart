import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/ai_provider.dart';
import 'package:ifutures/models/ai_service_status.dart';
import 'package:ifutures/models/ai_trade_direction_mode.dart';
import 'package:ifutures/models/kline.dart';
import 'package:ifutures/models/risk_settings.dart';
import 'package:ifutures/trading/ai_strategy.dart';
import 'package:ifutures/trading/strategy.dart';

void main() {
  test(
    'verifyConnection reports not configured when API key is missing',
    () async {
      final strategy = AiStrategy(
        apiUrl: AiProvider.groqChat.defaultUrl,
        apiKey: '',
        provider: AiProvider.groqChat,
        model: AiProvider.groqChat.defaultModel,
      );

      final result = await strategy.verifyConnection();

      expect(result.state, AiServiceState.notConfigured);
      expect(result.message, contains('API key is missing'));
    },
  );

  test('long-only mode blocks short AI calls', () async {
    final strategy = AiStrategy(
      apiUrl: 'https://example.com/ai',
      provider: AiProvider.customPromptApi,
      tradeDirectionMode: AiTradeDirectionMode.longOnly,
      leverage: 8,
      dio: _mockDio({
        'decision': 'sell',
        'orderType': 'market',
        'reason': 'Momentum is fading and a short looks better here.',
        'sizeFraction': 1.0,
        'leverage': 25,
      }),
    );

    final plan = await strategy.buildTradePlan(
      _sampleHistory(),
      riskSettings: const RiskSettings(
        stopLossPercent: 1.5,
        takeProfitPercent: 3.0,
        tradeQuantity: 0.05,
        leverage: 3,
      ),
    );

    expect(plan.signal, TradingSignal.hold);
    expect(plan.quantity, 0.0);
    expect(plan.leverage, 8);
    expect(plan.rationale, contains('LONG only'));
  });

  test(
    'ai budget converts USDT margin and leverage into max quantity',
    () async {
      final history = _sampleHistory();
      final currentPrice = history.last.close;
      final strategy = AiStrategy(
        apiUrl: 'https://example.com/ai',
        provider: AiProvider.customPromptApi,
        tradeDirectionMode: AiTradeDirectionMode.auto,
        leverage: 10,
        maxInvestmentUsdt: 20,
        dio: _mockDio({
          'decision': 'buy',
          'orderType': 'market',
          'reason': 'Trend and alignment support a long.',
          'sizeFraction': 1.0,
          'leverage': 50,
        }),
      );

      final plan = await strategy.buildTradePlan(
        history,
        riskSettings: const RiskSettings(
          stopLossPercent: 1.0,
          takeProfitPercent: 2.0,
          tradeQuantity: 0.01,
          leverage: 2,
        ),
      );

      expect(plan.signal, TradingSignal.buy);
      expect(plan.leverage, 10);
      expect(plan.quantity, closeTo((20 * 10) / currentPrice, 0.000001));
    },
  );

  test('non-finite AI numbers fail closed to safe plan values', () async {
    final history = _sampleHistory();
    final strategy = AiStrategy(
      apiUrl: 'https://example.com/ai',
      provider: AiProvider.customPromptApi,
      leverage: 5,
      maxInvestmentUsdt: 10,
      dio: _mockDio({
        'decision': 'buy',
        'orderType': 'limit',
        'targetEntryPrice': 'NaN',
        'takeProfitPercent': 'Infinity',
        'stopLossPercent': '-5',
        'sizeFraction': 'NaN',
        'confidence': 'NaN',
        'reason': 'Malformed numeric payload test.',
      }),
    );

    final plan = await strategy.buildTradePlan(
      history,
      riskSettings: const RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 2,
        tradeQuantity: 1,
        leverage: 5,
      ),
    );

    expect(plan.targetEntryPrice, isNotNull);
    expect(plan.targetEntryPrice!.isFinite, isTrue);
    expect(plan.takeProfitPercent, 2);
    expect(plan.stopLossPercent, 1);
    expect(plan.confidence, 0);
    expect(plan.quantity, isNotNull);
    expect(plan.quantity!.isFinite, isTrue);
  });

  test('AI confidence percentages normalize to zero-to-one', () async {
    final strategy = AiStrategy(
      apiUrl: 'https://example.com/ai',
      provider: AiProvider.customPromptApi,
      dio: _mockDio({
        'decision': 'buy',
        'orderType': 'market',
        'confidence': 75,
        'reason': 'Confidence normalization test.',
      }),
    );

    final plan = await strategy.buildTradePlan(_sampleHistory());

    expect(plan.confidence, 0.75);
  });
}

Dio _mockDio(Map<String, dynamic> payload) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: payload,
          ),
        );
      },
    ),
  );
  return dio;
}

List<Kline> _sampleHistory() {
  final start = DateTime.utc(2026, 4, 6, 0, 0);
  return List<Kline>.generate(60, (index) {
    final openTime = start.add(Duration(minutes: index));
    final closeTime = openTime.add(const Duration(minutes: 1));
    final close = 100 + index;
    return Kline(
      openTime: openTime,
      open: close - 0.3,
      high: close + 0.6,
      low: close - 0.8,
      close: close.toDouble(),
      volume: 1000 + (index * 10),
      closeTime: closeTime,
    );
  });
}
