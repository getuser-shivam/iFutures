import 'package:dio/dio.dart';
import '../models/kline.dart';
import 'strategy.dart';

class AiStrategy extends TradingStrategy {
  final String apiUrl;
  final String? apiKey;
  final Dio _dio = Dio();

  AiStrategy({required this.apiUrl, this.apiKey});

  @override
  String get name => "AI Analyst";

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    if (history.isEmpty) return TradingSignal.hold;

    final prompt = _buildPrompt(history);

    try {
      final response = await _dio.post(
        apiUrl,
        data: {'prompt': prompt},
        options: Options(headers: apiKey != null ? {'Authorization': 'Bearer $apiKey'} : {}),
      );

      final decision = response.data['decision']?.toString().toLowerCase();
      
      if (decision == 'buy') return TradingSignal.buy;
      if (decision == 'sell') return TradingSignal.sell;
      return TradingSignal.hold;
    } catch (e) {
      print('AI evaluation error: $e');
      return TradingSignal.hold;
    }
  }

  String _buildPrompt(List<Kline> history) {
    // Take last 10 candles for context
    final recent = history.length > 10 ? history.sublist(history.length - 10) : history;
    final data = recent.map((k) => 
      'T: ${k.openTime}, O: ${k.open}, H: ${k.high}, L: ${k.low}, C: ${k.close}, V: ${k.volume}'
    ).join('\n');

    return """
Analyze the following GALAUSDT candlestick data and provide a trading decision (BUY, SELL, or HOLD).
Consider short-term trends and volatility.

Data:
$data

Decision:
""";
  }
}
