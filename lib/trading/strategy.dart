import '../models/kline.dart';

enum TradingSignal { buy, sell, hold }

abstract class TradingStrategy {
  String get name;
  Future<TradingSignal> evaluate(List<Kline> history);
}
