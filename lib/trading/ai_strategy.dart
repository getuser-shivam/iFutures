import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/kline.dart';
import '../models/ai_provider.dart';
import '../models/manual_order.dart';
import 'strategy.dart';

class AiStrategy extends TradingStrategy {
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
    if (history.isEmpty) return TradingSignal.hold;

    final prompt = _buildPrompt(history);

    try {
      final decision = switch (provider) {
        AiProvider.customPromptApi => await _evaluateCustomPromptApi(prompt),
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
      return _decisionToSignal(decision);
    } catch (e) {
      print('AI evaluation error: $e');
      return TradingSignal.hold;
    }
  }

  Future<String> _evaluateCustomPromptApi(String prompt) async {
    final response = await _dio.post(
      apiUrl,
      data: {'prompt': prompt},
      options: Options(
        headers: apiKey != null && apiKey!.isNotEmpty
            ? {'Authorization': 'Bearer $apiKey'}
            : {},
      ),
    );
    return response.data['decision']?.toString().toLowerCase() ?? 'hold';
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
      return 'hold';
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
    return _extractDecision(raw ?? 'hold');
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

  TradingSignal _decisionToSignal(String decision) {
    if (decision == 'buy') return TradingSignal.buy;
    if (decision == 'sell') return TradingSignal.sell;
    return TradingSignal.hold;
  }

  String _extractDecision(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return 'hold';
    }

    try {
      final start = normalized.indexOf('{');
      final end = normalized.lastIndexOf('}');
      if (start != -1 && end > start) {
        final jsonMap = responseJson(normalized.substring(start, end + 1));
        final decision =
            jsonMap['decision'] ??
            jsonMap['signal'] ??
            jsonMap['action'] ??
            jsonMap['direction'];
        final parsed = decision?.toString().toLowerCase();
        if (parsed == 'buy' || parsed == 'sell' || parsed == 'hold') {
          return parsed!;
        }
      }
    } catch (_) {
      // Fall back to token search below.
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('buy')) return 'buy';
    if (lower.contains('sell')) return 'sell';
    return 'hold';
  }

  String _buildPrompt(List<Kline> history) {
    final recent = history.length > 10
        ? history.sublist(history.length - 10)
        : history;
    final currentPrice = recent.last.close;
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
Analyze the following candlestick data for $symbolLabel and provide a trading decision.
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
}
