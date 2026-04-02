import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/ai_context_snapshot.dart';
import '../models/ai_service_status.dart';
import '../models/ai_timeframe_snapshot.dart';
import '../models/kline.dart';
import '../models/ai_provider.dart';
import '../models/manual_order.dart';
import '../models/order_book_snapshot.dart';
import '../models/risk_settings.dart';
import '../services/ai_context_analyzer.dart';
import '../services/ai_multi_timeframe_analyzer.dart';
import '../services/performance_summary_calculator.dart';
import 'strategy.dart';

class AiStrategy extends TradingStrategy implements TradePlanningStrategy {
  final String apiUrl;
  final String? apiKey;
  final AiProvider provider;
  final String model;
  final String symbolLabel;
  final double? longBiasPrice;
  final double? shortBiasPrice;
  final ManualOrderType longOrderType;
  final ManualOrderType shortOrderType;
  final int leverage;
  final double takeProfitPercent;
  final double stopLossPercent;
  final Dio _dio;

  AiStrategy({
    required this.apiUrl,
    this.apiKey,
    this.provider = AiProvider.groqChat,
    this.model = '',
    this.symbolLabel = 'current futures pair',
    this.longBiasPrice,
    this.shortBiasPrice,
    this.longOrderType = ManualOrderType.limit,
    this.shortOrderType = ManualOrderType.limit,
    this.leverage = 1,
    this.takeProfitPercent = 0,
    this.stopLossPercent = 0,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  String get name => "AI Analyst";

  Future<AiServiceStatus> verifyConnection() async {
    final providerLabel = provider.label;
    final needsApiKey = provider != AiProvider.pollinationsText;
    final resolvedUrl = apiUrl.trim().isEmpty
        ? provider.defaultUrl
        : apiUrl.trim();
    final resolvedModel = _resolvedModel(provider.defaultModel);

    if (resolvedUrl.isEmpty) {
      return AiServiceStatus.notConfigured(
        providerLabel: providerLabel,
        message: 'AI API URL is not configured yet.',
      );
    }

    if (needsApiKey && (apiKey == null || apiKey!.trim().isEmpty)) {
      return AiServiceStatus.notConfigured(
        providerLabel: providerLabel,
        message: 'AI API key is missing for $providerLabel.',
      );
    }

    try {
      if (provider == AiProvider.customPromptApi) {
        final response = await _dio.post(
          resolvedUrl,
          data: {
            'prompt':
                'Connectivity test. Return exactly {"decision":"hold","reason":"ok"}',
          },
          options: Options(
            headers: apiKey != null && apiKey!.trim().isNotEmpty
                ? {'Authorization': 'Bearer ${apiKey!.trim()}'}
                : const <String, String>{},
            sendTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
          ),
        );
        return AiServiceStatus.active(
          providerLabel: providerLabel,
          checkedAt: DateTime.now(),
          message:
              '$providerLabel responded successfully using ${response.statusCode ?? 200}.',
        );
      }

      final headers = <String, dynamic>{'Content-Type': 'application/json'};
      if (needsApiKey && apiKey != null && apiKey!.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${apiKey!.trim()}';
      }

      final response = await _dio.post(
        resolvedUrl,
        data: {
          'model': resolvedModel,
          'messages': const [
            {
              'role': 'system',
              'content': 'You are a connectivity check. Reply briefly with OK.',
            },
            {'role': 'user', 'content': 'Connectivity test. Reply with OK.'},
          ],
          'temperature': 0.0,
          'max_tokens': 12,
        },
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );

      final hasChoices =
          response.data is Map<String, dynamic> &&
          (response.data as Map<String, dynamic>)['choices'] is List;
      final message = hasChoices
          ? '$providerLabel accepted the chat request and returned a model response.'
          : '$providerLabel responded successfully using ${response.statusCode ?? 200}.';
      return AiServiceStatus.active(
        providerLabel: providerLabel,
        checkedAt: DateTime.now(),
        message: message,
      );
    } on DioException catch (error) {
      final details = _errorDetails(error);
      return AiServiceStatus.attentionRequired(
        providerLabel: providerLabel,
        checkedAt: DateTime.now(),
        message: '$providerLabel connection failed: $details',
      );
    } catch (error) {
      return AiServiceStatus.attentionRequired(
        providerLabel: providerLabel,
        checkedAt: DateTime.now(),
        message: '$providerLabel connection failed: $error',
      );
    }
  }

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    final plan = await buildTradePlan(history);
    return plan.signal;
  }

  @override
  Future<StrategyTradePlan> buildTradePlan(
    List<Kline> history, {
    String? symbol,
    RiskSettings? riskSettings,
    StrategyAnalysisContext? context,
  }) async {
    final currentPrice = history.isEmpty ? 0.0 : history.last.close;
    final resolvedLeverage = riskSettings?.leverage ?? leverage;
    final resolvedTakeProfit =
        riskSettings?.takeProfitPercent ?? takeProfitPercent;
    final resolvedStopLoss = riskSettings?.stopLossPercent ?? stopLossPercent;
    final configuredQuantity = riskSettings?.tradeQuantity;

    if (history.isEmpty) {
      return StrategyTradePlan.hold(
        strategyName: name,
        currentPrice: currentPrice,
        leverage: resolvedLeverage,
        takeProfitPercent: resolvedTakeProfit,
        stopLossPercent: resolvedStopLoss,
        quantity: 0,
        rationale: 'AI mode is waiting for live candles before it can plan.',
        confidence: 0.0,
        sizeFraction: 0.0,
        longBiasPrice: longBiasPrice,
        shortBiasPrice: shortBiasPrice,
      );
    }

    final contextSnapshot = AiContextAnalyzer.analyze(
      history,
      context: context,
    );
    final multiTimeframeSnapshot = AiMultiTimeframeAnalyzer.analyze(history);
    final orderBookSnapshot = context?.orderBookSnapshot;

    final prompt = _buildPrompt(
      history,
      symbol: symbol,
      leverage: resolvedLeverage,
      takeProfitPercent: resolvedTakeProfit,
      stopLossPercent: resolvedStopLoss,
      quantity: configuredQuantity,
      contextSnapshot: contextSnapshot,
      multiTimeframeSnapshot: multiTimeframeSnapshot,
      orderBookSnapshot: orderBookSnapshot,
      context: context,
    );

    try {
      final raw = switch (provider) {
        AiProvider.customPromptApi => jsonEncode(
          await _evaluateCustomPromptApi(prompt),
        ),
        AiProvider.groqChat => await _evaluateOpenAiCompatibleChat(
          prompt,
          defaultUrl: AiProvider.groqChat.defaultUrl,
          defaultModel: AiProvider.groqChat.defaultModel,
          requireApiKey: true,
        ),
        AiProvider.pollinationsText => await _evaluateOpenAiCompatibleChat(
          prompt,
          defaultUrl: AiProvider.pollinationsText.defaultUrl,
          defaultModel: AiProvider.pollinationsText.defaultModel,
          requireApiKey: false,
        ),
      };

      final payload = _extractJsonMap(raw);
      final signal = _decisionToSignal(
        (payload['decision'] ??
                payload['signal'] ??
                payload['action'] ??
                payload['direction'])
            ?.toString()
            .toLowerCase(),
      );
      final orderType = signal == TradingSignal.hold
          ? null
          : (_parseOrderType(payload['orderType']?.toString()) ??
                _fallbackOrderType(history, signal, orderBookSnapshot));
      final targetEntryPrice =
          _asDouble(
            payload['targetEntryPrice'] ??
                payload['entryPrice'] ??
                payload['price'],
          ) ??
          suggestTargetEntryPrice(currentPrice, signal, orderType);
      final planLeverage =
          _asInt(payload['leverage'])?.clamp(1, 125) ?? resolvedLeverage;
      final planTakeProfit =
          _asDouble(payload['takeProfitPercent']) ?? resolvedTakeProfit;
      final planStopLoss =
          _asDouble(payload['stopLossPercent']) ?? resolvedStopLoss;
      final confidence = _asDouble(payload['confidence']);
      final sizeFraction = _parseSizeFraction(
        payload,
        signal: signal,
        fallback: contextSnapshot.suggestedSizeFraction,
      );
      final alignedSizeFraction = _alignmentAdjustedSizeFraction(
        sizeFraction,
        signal: signal,
        multiTimeframeSnapshot: multiTimeframeSnapshot,
      );
      final microstructureAdjustedSizeFraction = _orderBookAdjustedSizeFraction(
        alignedSizeFraction,
        orderBookSnapshot: orderBookSnapshot,
      );
      final plannedQuantity = _plannedQuantity(
        signal: signal,
        configuredQuantity: configuredQuantity,
        sizeFraction: microstructureAdjustedSizeFraction,
      );
      final marketRegime =
          payload['marketRegime']?.toString().trim().isNotEmpty == true
          ? payload['marketRegime'].toString().trim()
          : contextSnapshot.marketRegime;
      final riskPosture =
          payload['riskPosture']?.toString().trim().isNotEmpty == true
          ? payload['riskPosture'].toString().trim()
          : contextSnapshot.riskPosture;
      final tradeReviewState =
          payload['tradeReviewState']?.toString().trim().isNotEmpty == true
          ? payload['tradeReviewState'].toString().trim()
          : contextSnapshot.tradeReviewState;
      final timeframeAlignment =
          payload['timeframeAlignment']?.toString().trim().isNotEmpty == true
          ? payload['timeframeAlignment'].toString().trim()
          : multiTimeframeSnapshot.alignment;
      final executionHint =
          payload['executionHint']?.toString().trim().isNotEmpty == true
          ? payload['executionHint'].toString().trim()
          : orderBookSnapshot?.executionHint;
      final rationale = payload['reason']?.toString().trim().isNotEmpty == true
          ? payload['reason'].toString().trim()
          : _fallbackReason(
              signal,
              orderType,
              contextSnapshot: contextSnapshot,
              multiTimeframeSnapshot: multiTimeframeSnapshot,
              orderBookSnapshot: orderBookSnapshot,
            );

      return StrategyTradePlan(
        strategyName: name,
        signal: signal,
        orderType: orderType,
        currentPrice: currentPrice,
        targetEntryPrice: targetEntryPrice,
        leverage: planLeverage,
        takeProfitPercent: planTakeProfit,
        stopLossPercent: planStopLoss,
        quantity: plannedQuantity,
        rationale: rationale,
        generatedAt: DateTime.now(),
        confidence: confidence,
        sizeFraction: microstructureAdjustedSizeFraction,
        longBiasPrice: longBiasPrice,
        shortBiasPrice: shortBiasPrice,
        marketRegime: marketRegime,
        riskPosture: riskPosture,
        tradeReviewState: tradeReviewState,
        timeframeAlignment: timeframeAlignment,
        executionHint: executionHint,
        spreadPercent: orderBookSnapshot?.spreadPercent,
        orderBookImbalancePercent: orderBookSnapshot?.imbalancePercent,
        estimatedBuySlippagePercent:
            orderBookSnapshot?.estimatedBuySlippagePercent,
        estimatedSellSlippagePercent:
            orderBookSnapshot?.estimatedSellSlippagePercent,
        timeframeSnapshots: multiTimeframeSnapshot.timeframes,
      );
    } catch (e) {
      print('AI evaluation error: $e');
      final details = switch (e) {
        DioException() => e.response?.data?.toString() ?? e.message ?? '$e',
        _ => '$e',
      };
      return StrategyTradePlan.hold(
        strategyName: name,
        currentPrice: currentPrice,
        leverage: resolvedLeverage,
        takeProfitPercent: resolvedTakeProfit,
        stopLossPercent: resolvedStopLoss,
        quantity: 0,
        rationale: 'AI planning failed: $details',
        confidence: 0.0,
        sizeFraction: 0.0,
        longBiasPrice: longBiasPrice,
        shortBiasPrice: shortBiasPrice,
        marketRegime: contextSnapshot.marketRegime,
        riskPosture: contextSnapshot.riskPosture,
        tradeReviewState: contextSnapshot.tradeReviewState,
        timeframeAlignment: multiTimeframeSnapshot.alignment,
        executionHint: orderBookSnapshot?.executionHint,
        spreadPercent: orderBookSnapshot?.spreadPercent,
        orderBookImbalancePercent: orderBookSnapshot?.imbalancePercent,
        estimatedBuySlippagePercent:
            orderBookSnapshot?.estimatedBuySlippagePercent,
        estimatedSellSlippagePercent:
            orderBookSnapshot?.estimatedSellSlippagePercent,
        timeframeSnapshots: multiTimeframeSnapshot.timeframes,
      );
    }
  }

  Future<Map<String, dynamic>> _evaluateCustomPromptApi(String prompt) async {
    final response = await _dio.post(
      apiUrl,
      data: {'prompt': prompt},
      options: Options(
        headers: apiKey != null && apiKey!.isNotEmpty
            ? {'Authorization': 'Bearer $apiKey'}
            : {},
      ),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{
      'decision': response.data?.toString().toLowerCase() ?? 'hold',
    };
  }

  Future<String> _evaluateOpenAiCompatibleChat(
    String prompt, {
    required String defaultUrl,
    required String defaultModel,
    required bool requireApiKey,
  }) async {
    final resolvedUrl = apiUrl.trim().isEmpty ? defaultUrl : apiUrl.trim();
    final resolvedModel = _resolvedModel(defaultModel);
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    if (requireApiKey && (apiKey == null || apiKey!.trim().isEmpty)) {
      return '{"decision":"hold","reason":"API key is missing for the selected AI provider."}';
    }
    if (requireApiKey && apiKey != null && apiKey!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _dio.post(
      resolvedUrl,
      data: {
        'model': resolvedModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a futures trading assistant. Return a concise decision based on the user rules and recent candles.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.2,
      },
      options: Options(headers: headers),
    );

    String? raw;
    if (response.data is Map<String, dynamic>) {
      final payload = response.data as Map<String, dynamic>;
      final choices = payload['choices'];
      if (choices is List && choices.isNotEmpty) {
        final firstChoice = choices.first;
        if (firstChoice is Map<String, dynamic>) {
          final message = firstChoice['message'];
          if (message is Map<String, dynamic>) {
            raw = message['content']?.toString();
          }
        }
      }
    } else {
      raw = response.data?.toString();
    }
    return raw ??
        '{"decision":"hold","reason":"AI provider returned an empty response."}';
  }

  String _resolvedModel(String fallback) {
    final trimmed = model.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    if (provider == AiProvider.groqChat && trimmed.toLowerCase() == 'openai') {
      return fallback;
    }
    return trimmed;
  }

  TradingSignal _decisionToSignal(String? decision) {
    if (decision == 'buy') return TradingSignal.buy;
    if (decision == 'sell') return TradingSignal.sell;
    if (decision == 'long') return TradingSignal.buy;
    if (decision == 'short') return TradingSignal.sell;
    return TradingSignal.hold;
  }

  Map<String, dynamic> _extractJsonMap(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return const <String, dynamic>{'decision': 'hold'};
    }

    try {
      final start = normalized.indexOf('{');
      final end = normalized.lastIndexOf('}');
      if (start != -1 && end > start) {
        return responseJson(normalized.substring(start, end + 1));
      }
    } catch (_) {
      // Fall back to token search below.
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('buy') || lower.contains('long')) {
      return <String, dynamic>{'decision': 'buy', 'reason': normalized};
    }
    if (lower.contains('sell') || lower.contains('short')) {
      return <String, dynamic>{'decision': 'sell', 'reason': normalized};
    }
    return <String, dynamic>{'decision': 'hold', 'reason': normalized};
  }

  String _buildPrompt(
    List<Kline> history, {
    String? symbol,
    required int leverage,
    required double takeProfitPercent,
    required double stopLossPercent,
    required double? quantity,
    required AiContextSnapshot contextSnapshot,
    required AiMultiTimeframeSnapshot multiTimeframeSnapshot,
    required OrderBookSnapshot? orderBookSnapshot,
    StrategyAnalysisContext? context,
  }) {
    final recent = history.length > 10
        ? history.sublist(history.length - 10)
        : history;
    final currentPrice = recent.last.close;
    final targetSymbol = symbol ?? symbolLabel;
    final data = recent
        .map(
          (k) =>
              'T: ${k.openTime}, O: ${k.open}, H: ${k.high}, L: ${k.low}, C: ${k.close}, V: ${k.volume}',
        )
        .join('\n');
    final longBias = longBiasPrice == null
        ? 'No fixed long zone was configured.'
        : 'Long bias becomes stronger at or below $longBiasPrice using ${longOrderType.label.toUpperCase()} entries.';
    final shortBias = shortBiasPrice == null
        ? 'No fixed short zone was configured.'
        : 'Short bias becomes stronger at or above $shortBiasPrice using ${shortOrderType.label.toUpperCase()} entries.';
    final accountSummary = _buildAccountSummary(
      context,
      leverage: leverage,
      currentPrice: currentPrice,
      quantity: quantity,
    );
    final tradeReview = _buildTradeReview(context);
    final aiContext = _buildAiContextSummary(contextSnapshot);
    final multiTimeframeContext = _buildMultiTimeframeSummary(
      multiTimeframeSnapshot,
    );
    final orderBookContext = _buildOrderBookSummary(orderBookSnapshot);
    final portfolioRules = context == null
        ? '- Portfolio and trade-history context is not available for this request.'
        : '- Factor in recent realized performance, current exposure, and remaining available balance before choosing side, leverage, and order type.\n'
              '- If the recent trade review shows repeated losses or the account is already heavily exposed, reduce aggression or prefer HOLD.\n'
              '- Use MARKET only when momentum is strong, LIMIT/POST_ONLY when price is near a planned level, and SCALED when volatility is wide enough to justify staged execution.\n'
              '- Choose a sizeFraction between 0.15 and 1.0 for actionable trades. Treat the configured quantity as the max size, not a mandatory full-size trade.\n'
              '- Respect multi-timeframe alignment. If 1m, 5m, and 15m disagree, reduce size or prefer HOLD over forcing a trade.\n'
              '- Respect Binance order book conditions. Wide spread or high market slippage should push you toward LIMIT, POST_ONLY, or SCALED entries instead of MARKET.';

    return """
Analyze the following candlestick data for $targetSymbol and provide a trading decision.
Use the trader rules, portfolio context, and recent trade review below before deciding.

Trader rules:
- Current price snapshot: $currentPrice
- $longBias
- $shortBias
- Maximum leverage to consider: ${leverage}x
- Maximum base quantity: ${quantity?.toStringAsFixed(6) ?? 'not configured'}
- Take profit target: ${takeProfitPercent.toStringAsFixed(2)}%
- Stop loss limit: ${stopLossPercent.toStringAsFixed(2)}%
- If price is between the long and short zones with no clear edge, prefer HOLD.
- $portfolioRules
- Return JSON only with:
  {"decision":"BUY|SELL|HOLD","direction":"LONG|SHORT|NONE","orderType":"MARKET|LIMIT|POST_ONLY|SCALED","leverage":number,"takeProfitPercent":number,"stopLossPercent":number,"sizeFraction":0.0,"confidence":0.0,"marketRegime":"short label","riskPosture":"short label","tradeReviewState":"short label","timeframeAlignment":"short label","reason":"short reason that references both market and portfolio context"}

Portfolio snapshot:
$accountSummary

Recent trade review:
$tradeReview

Derived AI context:
$aiContext

Multi-timeframe context:
$multiTimeframeContext

Order book context:
$orderBookContext

Data:
$data
""";
  }

  String _buildAiContextSummary(AiContextSnapshot snapshot) {
    return '- Market regime: ${snapshot.marketRegime}\n'
        '- Risk posture: ${snapshot.riskPosture}\n'
        '- Trade review state: ${snapshot.tradeReviewState}\n'
        '- Short momentum: ${snapshot.shortMomentumPercent.toStringAsFixed(2)}%\n'
        '- Medium momentum: ${snapshot.mediumMomentumPercent.toStringAsFixed(2)}%\n'
        '- Range width: ${snapshot.rangeWidthPercent.toStringAsFixed(2)}%\n'
        '- Range position: ${snapshot.rangePositionPercent.toStringAsFixed(0)}%\n'
        '- Candle volatility: ${snapshot.volatilityPercent.toStringAsFixed(2)}%\n'
        '- Volume ratio: ${snapshot.volumeRatio.toStringAsFixed(2)}x\n'
        '- RSI 14: ${snapshot.rsi14.toStringAsFixed(1)}\n'
        '- Suggested size fraction from local context: ${snapshot.suggestedSizeFraction.toStringAsFixed(2)}';
  }

  String _buildMultiTimeframeSummary(AiMultiTimeframeSnapshot snapshot) {
    if (snapshot.timeframes.isEmpty) {
      return 'No timeframe alignment was available.';
    }

    final lines = snapshot.timeframes
        .map(
          (entry) =>
              '- ${entry.label}: ${entry.regime}, short ${entry.shortMomentumPercent.toStringAsFixed(2)}%, medium ${entry.mediumMomentumPercent.toStringAsFixed(2)}%, range ${entry.rangePositionPercent.toStringAsFixed(0)}%, RSI ${entry.rsi14.toStringAsFixed(1)}',
        )
        .join('\n');
    return '$lines\n- Alignment: ${snapshot.alignment}';
  }

  String _buildOrderBookSummary(OrderBookSnapshot? snapshot) {
    if (snapshot == null) {
      return 'Order book snapshot unavailable.';
    }

    return '- Best bid: ${_formatPrice(snapshot.bestBid)}\n'
        '- Best ask: ${_formatPrice(snapshot.bestAsk)}\n'
        '- Spread: ${snapshot.spreadPercent?.toStringAsFixed(4) ?? '--'}%\n'
        '- Bid/ask imbalance: ${snapshot.imbalancePercent.toStringAsFixed(2)}%\n'
        '- Estimated market buy slippage: ${snapshot.estimatedBuySlippagePercent?.toStringAsFixed(4) ?? '--'}%\n'
        '- Estimated market sell slippage: ${snapshot.estimatedSellSlippagePercent?.toStringAsFixed(4) ?? '--'}%\n'
        '- Execution hint: ${snapshot.executionHint}\n'
        '- Captured at: ${snapshot.capturedAt}';
  }

  String _buildAccountSummary(
    StrategyAnalysisContext? context, {
    required int leverage,
    required double currentPrice,
    required double? quantity,
  }) {
    if (context == null) {
      return 'Portfolio snapshot unavailable.';
    }

    final openPosition = context.openPosition;
    final plannedExposure = quantity == null ? null : quantity * currentPrice;
    final plannedMargin = plannedExposure == null || leverage <= 0
        ? null
        : plannedExposure / leverage;

    final parts = <String>[
      'Wallet balance: ${_formatUsdt(context.walletBalance)}',
      'Available balance: ${_formatUsdt(context.availableBalance)}',
      'Open positions: ${context.openPositionCount?.toString() ?? 'unknown'}',
      'Planned exposure at current price: ${_formatUsdt(plannedExposure)}',
      'Estimated margin for planned trade: ${_formatUsdt(plannedMargin)}',
      if (openPosition == null)
        'Current symbol position: none'
      else
        'Current symbol position: ${openPosition.isLong ? 'LONG' : 'SHORT'} ${_formatNumber(openPosition.quantity)} @ ${_formatPrice(openPosition.entryPrice)}',
      if (context.accountSyncedAt != null)
        'Account synced at: ${context.accountSyncedAt}',
      if (context.accountStatusMessage?.trim().isNotEmpty == true)
        'Account status note: ${context.accountStatusMessage!.trim()}',
    ];

    return parts.join('\n');
  }

  String _buildTradeReview(StrategyAnalysisContext? context) {
    if (context == null) {
      return 'Trade review unavailable.';
    }

    final symbolSummary = PerformanceSummaryCalculator.calculate(
      context.symbolTrades,
    );
    final accountSummary = PerformanceSummaryCalculator.calculate(
      context.accountTrades,
    );
    final recentSymbolTrades = context.symbolTrades.length > 5
        ? context.symbolTrades.sublist(context.symbolTrades.length - 5)
        : context.symbolTrades;
    final recentAccountTrades = context.accountTrades.length > 8
        ? context.accountTrades.sublist(context.accountTrades.length - 8)
        : context.accountTrades;

    final lines = <String>[
      'Symbol summary: ${_summaryLine(symbolSummary)}',
      'Tracked account summary: ${_summaryLine(accountSummary)}',
      'Recent symbol fills:',
      if (recentSymbolTrades.isEmpty)
        '- none'
      else
        ...recentSymbolTrades.map(_tradeLine),
      'Recent tracked-account fills:',
      if (recentAccountTrades.isEmpty)
        '- none'
      else
        ...recentAccountTrades.map(_tradeLine),
    ];

    return lines.join('\n');
  }

  String _summaryLine(dynamic summary) {
    return '${summary.totalTrades} closed trades, '
        'win rate ${summary.winRate.toStringAsFixed(0)}%, '
        'total PnL ${summary.totalPnL.toStringAsFixed(4)}, '
        'profit factor ${summary.profitFactor.isInfinite ? 'INF' : summary.profitFactor.toStringAsFixed(2)}.';
  }

  String _tradeLine(dynamic trade) {
    final pnl = trade.realizedPnl == null
        ? 'open/flat'
        : trade.realizedPnl!.toStringAsFixed(4);
    return '- ${trade.symbol} ${trade.side} ${trade.kind} qty ${_formatNumber(trade.quantity)} @ ${_formatPrice(trade.price)} pnl $pnl';
  }

  String _formatPrice(double? value) {
    if (value == null) {
      return '--';
    }
    return value >= 100 ? value.toStringAsFixed(2) : value.toStringAsFixed(6);
  }

  String _formatUsdt(double? value) {
    if (value == null) {
      return 'unknown';
    }
    return '${value.toStringAsFixed(2)} USDT';
  }

  String _formatNumber(double? value) {
    if (value == null) {
      return '--';
    }
    return value.toStringAsFixed(value >= 100 ? 2 : 6);
  }

  Map<String, dynamic> responseJson(String value) {
    if (value.isEmpty) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  ManualOrderType _fallbackOrderType(
    List<Kline> history,
    TradingSignal signal,
    OrderBookSnapshot? orderBookSnapshot,
  ) {
    final heuristicType = selectAutoOrderType(history, signal);
    if (orderBookSnapshot != null && signal != TradingSignal.hold) {
      final spread = orderBookSnapshot.spreadPercent ?? 0.0;
      final worstSlippage =
          (orderBookSnapshot.estimatedBuySlippagePercent ?? 0.0) >
              (orderBookSnapshot.estimatedSellSlippagePercent ?? 0.0)
          ? (orderBookSnapshot.estimatedBuySlippagePercent ?? 0.0)
          : (orderBookSnapshot.estimatedSellSlippagePercent ?? 0.0);

      if (spread >= 0.12 || worstSlippage >= 0.18) {
        return ManualOrderType.scaled;
      }
      if (spread <= 0.02 && worstSlippage <= 0.03) {
        return ManualOrderType.market;
      }
      if (spread <= 0.05) {
        return ManualOrderType.limit;
      }
      return ManualOrderType.postOnly;
    }

    return switch (signal) {
      TradingSignal.buy =>
        longBiasPrice != null ? longOrderType : heuristicType,
      TradingSignal.sell =>
        shortBiasPrice != null ? shortOrderType : heuristicType,
      TradingSignal.hold => heuristicType,
    };
  }

  String _fallbackReason(
    TradingSignal signal,
    ManualOrderType? orderType, {
    required AiContextSnapshot contextSnapshot,
    required AiMultiTimeframeSnapshot multiTimeframeSnapshot,
    required OrderBookSnapshot? orderBookSnapshot,
  }) {
    final bookNote = orderBookSnapshot == null
        ? 'without live book depth'
        : 'with ${orderBookSnapshot.executionHint.toLowerCase()}';
    return switch (signal) {
      TradingSignal.buy =>
        'AI favors a long plan in a ${contextSnapshot.marketRegime.toLowerCase()} regime with ${multiTimeframeSnapshot.alignment.toLowerCase()}, ${contextSnapshot.riskPosture.toLowerCase()} risk posture, $bookNote, and ${orderType?.label ?? 'watching'} execution.',
      TradingSignal.sell =>
        'AI favors a short plan in a ${contextSnapshot.marketRegime.toLowerCase()} regime with ${multiTimeframeSnapshot.alignment.toLowerCase()}, ${contextSnapshot.riskPosture.toLowerCase()} risk posture, $bookNote, and ${orderType?.label ?? 'watching'} execution.',
      TradingSignal.hold =>
        'AI sees ${multiTimeframeSnapshot.alignment.toLowerCase()} across a ${contextSnapshot.marketRegime.toLowerCase()} regime with ${contextSnapshot.tradeReviewState.toLowerCase()} trade review and $bookNote, so it prefers to wait.',
    };
  }

  double _parseSizeFraction(
    Map<String, dynamic> payload, {
    required TradingSignal signal,
    required double fallback,
  }) {
    if (signal == TradingSignal.hold) {
      return 0.0;
    }

    final raw =
        _asDouble(
          payload['sizeFraction'] ??
              payload['allocation'] ??
              payload['sizePercent'] ??
              payload['qtyFraction'],
        ) ??
        fallback;
    final normalized = raw > 1 ? raw / 100 : raw;
    return normalized.clamp(0.15, 1.0).toDouble();
  }

  double _alignmentAdjustedSizeFraction(
    double sizeFraction, {
    required TradingSignal signal,
    required AiMultiTimeframeSnapshot multiTimeframeSnapshot,
  }) {
    if (signal == TradingSignal.hold) {
      return 0.0;
    }

    final alignment = multiTimeframeSnapshot.alignment;
    var adjusted = sizeFraction;

    if ((signal == TradingSignal.buy && alignment == 'Bullish Alignment') ||
        (signal == TradingSignal.sell && alignment == 'Bearish Alignment')) {
      adjusted += 0.10;
    } else if ((signal == TradingSignal.buy &&
            alignment == 'Bearish Alignment') ||
        (signal == TradingSignal.sell && alignment == 'Bullish Alignment')) {
      adjusted -= 0.25;
    } else if (alignment == 'Mixed Alignment' ||
        alignment == 'Compression Alignment') {
      adjusted -= 0.08;
    }

    return adjusted.clamp(0.15, 1.0).toDouble();
  }

  double _orderBookAdjustedSizeFraction(
    double sizeFraction, {
    required OrderBookSnapshot? orderBookSnapshot,
  }) {
    if (orderBookSnapshot == null) {
      return sizeFraction;
    }

    var adjusted = sizeFraction;
    final spread = orderBookSnapshot.spreadPercent ?? 0.0;
    final worstSlippage =
        (orderBookSnapshot.estimatedBuySlippagePercent ?? 0.0) >
            (orderBookSnapshot.estimatedSellSlippagePercent ?? 0.0)
        ? (orderBookSnapshot.estimatedBuySlippagePercent ?? 0.0)
        : (orderBookSnapshot.estimatedSellSlippagePercent ?? 0.0);

    if (spread >= 0.12 || worstSlippage >= 0.18) {
      adjusted -= 0.20;
    } else if (spread >= 0.06 || worstSlippage >= 0.10) {
      adjusted -= 0.10;
    } else if (spread <= 0.02 && worstSlippage <= 0.03) {
      adjusted += 0.05;
    }

    return adjusted.clamp(0.15, 1.0).toDouble();
  }

  double? _plannedQuantity({
    required TradingSignal signal,
    required double? configuredQuantity,
    required double sizeFraction,
  }) {
    if (configuredQuantity == null || configuredQuantity <= 0) {
      return null;
    }
    if (signal == TradingSignal.hold) {
      return 0.0;
    }
    return configuredQuantity * sizeFraction;
  }

  ManualOrderType? _parseOrderType(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return switch (normalized) {
      'market' => ManualOrderType.market,
      'limit' => ManualOrderType.limit,
      'post_only' || 'post only' || 'post-only' => ManualOrderType.postOnly,
      'scaled' || 'scale' => ManualOrderType.scaled,
      _ => null,
    };
  }

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  String _errorDetails(DioException error) {
    final statusCode = error.response?.statusCode;
    final payload = error.response?.data;
    final payloadText = payload == null ? null : payload.toString();
    if (statusCode != null && payloadText != null && payloadText.isNotEmpty) {
      return 'HTTP $statusCode: $payloadText';
    }
    if (statusCode != null) {
      return 'HTTP $statusCode';
    }
    return error.message ?? error.toString();
  }
}
