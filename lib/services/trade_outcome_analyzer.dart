import '../models/ai_trade_outcome_snapshot.dart';
import '../models/trade.dart';

class TradeOutcomeAnalyzer {
  const TradeOutcomeAnalyzer._();

  static List<AiTradeOutcomeSnapshot> analyze(
    List<Trade> trades, {
    int limit = 5,
  }) {
    final exits =
        trades
            .where((trade) => trade.kind == 'EXIT' && trade.realizedPnl != null)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return exits.reversed.take(limit).map(_fromTrade).toList(growable: false);
  }

  static String summarizeBias(List<AiTradeOutcomeSnapshot> outcomes) {
    if (outcomes.isEmpty) {
      return 'Unproven';
    }

    final latest = outcomes.first;
    final wins = outcomes.where((item) => item.isWin).length;
    final losses = outcomes.where((item) => item.isLoss).length;

    if (latest.isLoss &&
        latest.reason.toLowerCase().contains('stop') &&
        losses >= 2) {
      return 'Cooling after stop losses';
    }
    if (losses >= wins + 2) {
      return 'Defensive after losses';
    }
    if (latest.isWin && wins >= losses + 1) {
      return 'Pressing recent edge';
    }
    if (wins == losses) {
      return 'Mixed recent outcomes';
    }
    return wins > losses ? 'Constructive recent outcomes' : 'Cautious review';
  }

  static AiTradeOutcomeSnapshot _fromTrade(Trade trade) {
    final realizedPnl = trade.realizedPnl ?? 0.0;
    final reason = (trade.reason ?? 'unknown').replaceAll('_', ' ');
    final positionSideLabel = trade.side == 'SELL' ? 'LONG' : 'SHORT';

    final outcomeLabel = switch ((realizedPnl >= 0, reason.toLowerCase())) {
      (true, final reasonText) when reasonText.contains('take profit') =>
        'Take-profit win',
      (false, final reasonText) when reasonText.contains('stop loss') =>
        'Stopped out',
      (true, _) => 'Profitable exit',
      (false, _) => 'Losing exit',
    };

    return AiTradeOutcomeSnapshot(
      symbol: trade.symbol,
      positionSideLabel: positionSideLabel,
      realizedPnl: realizedPnl,
      quantity: trade.quantity,
      exitPrice: trade.price,
      closedAt: trade.timestamp,
      reason: reason,
      strategy: trade.strategy,
      outcomeLabel: outcomeLabel,
    );
  }
}
