import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/kline.dart';
import '../models/ai_provider.dart';
import '../models/manual_order.dart';
import '../models/risk_settings.dart';
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
  final Dio _dio = Dio();

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
  });

  @override
  String get name => "AI Analyst";

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
  }) async {
    final currentPrice = history.isEmpty ? 0.0 : history.last.close;
    final resolvedLeverage = riskSettings?.leverage ?? leverage;
    final resolvedTakeProfit =
        riskSettings?.takeProfitPercent ?? takeProfitPercent;
    final resolvedStopLoss = riskSettings?.stopLossPercent ?? stopLossPercent;

    if (history.isEmpty) {
      return StrategyTradePlan.hold(
        strategyName: name,
        currentPrice: currentPrice,
        leverage: resolvedLeverage,
        takeProfitPercent: resolvedTakeProfit,
        stopLossPercent: resolvedStopLoss,
        rationale: 'AI mode is waiting for live candles before it can plan.',
        confidence: 0.0,
        longBiasPrice: longBiasPrice,
        shortBiasPrice: shortBiasPrice,
      );
    }

    final prompt = _buildPrompt(
      history,
      symbol: symbol,
      leverage: resolvedLeverage,
      takeProfitPercent: resolvedTakeProfit,
      stopLossPercent: resolvedStopLoss,
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
                _fallbackOrderType(history, signal));
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
      final rationale = payload['reason']?.toString().trim().isNotEmpty == true
          ? payload['reason'].toString().trim()
          : _fallbackReason(signal, orderType);

      return StrategyTradePlan(
        strategyName: name,
        signal: signal,
        orderType: orderType,
        currentPrice: currentPrice,
        targetEntryPrice: targetEntryPrice,
        leverage: planLeverage,
        takeProfitPercent: planTakeProfit,
        stopLossPercent: planStopLoss,
        rationale: rationale,
        generatedAt: DateTime.now(),
        confidence: confidence,
        longBiasPrice: longBiasPrice,
        shortBiasPrice: shortBiasPrice,
      );
    } catch (e) {
      print('AI evaluation error: $e');
      return StrategyTradePlan.hold(
        strategyName: name,
        currentPrice: currentPrice,
        leverage: resolvedLeverage,
        takeProfitPercent: resolvedTakeProfit,
        stopLossPercent: resolvedStopLoss,
        rationale:
            'AI planning failed, so the strategy is waiting. Check the AI provider settings or imported key.',
        confidence: 0.0,
        longBiasPrice: longBiasPrice,
        shortBiasPrice: shortBiasPrice,
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
        'jsonMode': false,
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

    return """
Analyze the following candlestick data for $targetSymbol and provide a trading decision.
Use the trader rules below before deciding.

Trader rules:
- Current price snapshot: $currentPrice
- $longBias
- $shortBias
- Maximum leverage to consider: ${leverage}x
- Take profit target: ${takeProfitPercent.toStringAsFixed(2)}%
- Stop loss limit: ${stopLossPercent.toStringAsFixed(2)}%
- If price is between the long and short zones with no clear edge, prefer HOLD.
- Return JSON only with:
  {"decision":"BUY|SELL|HOLD","direction":"LONG|SHORT|NONE","orderType":"MARKET|LIMIT|POST_ONLY|SCALED","leverage":number,"takeProfitPercent":number,"stopLossPercent":number,"reason":"short reason"}

Data:
$data
""";
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
  ) {
    final heuristicType = selectAutoOrderType(history, signal);
    return switch (signal) {
      TradingSignal.buy =>
        longBiasPrice != null ? longOrderType : heuristicType,
      TradingSignal.sell =>
        shortBiasPrice != null ? shortOrderType : heuristicType,
      TradingSignal.hold => heuristicType,
    };
  }

  String _fallbackReason(TradingSignal signal, ManualOrderType? orderType) {
    return switch (signal) {
      TradingSignal.buy =>
        'AI favors a long plan near the configured support zone and prefers ${orderType?.label ?? 'watching'} execution.',
      TradingSignal.sell =>
        'AI favors a short plan near the configured resistance zone and prefers ${orderType?.label ?? 'watching'} execution.',
      TradingSignal.hold =>
        'AI sees no strong edge between the configured zones, so it prefers to wait.',
    };
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
}
