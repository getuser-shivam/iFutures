import '../models/kline.dart';
import 'strategy.dart';

class RsiStrategy extends TradingStrategy {
  final int period;
  final double overbought;
  final double oversold;

  RsiStrategy({
    this.period = 14,
    this.overbought = 70.0,
    this.oversold = 30.0,
  });

  @override
  String get name => "RSI Algorithm";

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    if (history.length < period + 1) return TradingSignal.hold;

    final rsi = _calculateRsi(history);
    
    if (rsi < oversold) {
      return TradingSignal.buy;
    } else if (rsi > overbought) {
      return TradingSignal.sell;
    }
    
    return TradingSignal.hold;
  }

  double _calculateRsi(List<Kline> history) {
    // Simple RSI calculation logic
    double avgGain = 0.0;
    double avgLoss = 0.0;

    for (int i = 1; i <= period; i++) {
      final change = history[history.length - i].close - history[history.length - i - 1].close;
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss -= change;
      }
    }

    avgGain /= period;
    avgLoss /= period;

    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }
}
