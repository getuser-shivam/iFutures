import '../models/kline.dart';
import 'strategy.dart';

class ManualStrategy extends TradingStrategy {
  @override
  String get name => 'Manual';

  @override
  Future<TradingSignal> evaluate(List<Kline> history) async {
    return TradingSignal.hold;
  }
}
