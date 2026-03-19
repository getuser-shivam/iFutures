import '../models/backtest_result.dart';
import '../models/kline.dart';
import '../models/performance_summary.dart';
import '../models/position.dart';
import '../models/risk_settings.dart';
import '../models/trade.dart';
import 'performance_summary_calculator.dart';
import '../trading/strategy.dart';

class BacktestService {
  const BacktestService();

  Future<BacktestResult> run({
    required String symbol,
    required TradingStrategy strategy,
    required RiskSettings riskSettings,
    required List<Kline> klines,
    double startingBalance = 1000.0,
  }) async {
    if (klines.isEmpty) {
      final now = DateTime.now();
      return BacktestResult(
        symbol: symbol,
        strategyName: strategy.name,
        periodStart: now,
        periodEnd: now,
        candlesProcessed: 0,
        startingBalance: startingBalance,
        endingBalance: startingBalance,
        equityCurve: List<double>.unmodifiable([startingBalance]),
        trades: const [],
        summary: PerformanceSummary.empty(),
      );
    }

    final history = <Kline>[];
    final trades = <Trade>[];
    final equityCurve = <double>[startingBalance];
    Position? openPosition;
    double balance = startingBalance;

    for (final candle in klines) {
      history.add(candle);

      if (openPosition != null) {
        final maybeExit = _checkRisk(
          position: openPosition,
          symbol: symbol,
          currentPrice: candle.close,
          timestamp: candle.closeTime,
          strategyName: strategy.name,
          reason: null,
          riskSettings: riskSettings,
        );

        if (maybeExit != null) {
          trades.add(maybeExit.trade);
          balance += maybeExit.pnl;
          equityCurve.add(balance);
          openPosition = null;
        }
      }

      final signal = await strategy.evaluate(List<Kline>.unmodifiable(history));
      if (signal == TradingSignal.hold) {
        continue;
      }

      final desiredSide = signal == TradingSignal.buy
          ? PositionSide.long
          : PositionSide.short;
      final signalResult = _handleSignal(
        desiredSide: desiredSide,
        symbol: symbol,
        price: candle.close,
        timestamp: candle.closeTime,
        strategyName: strategy.name,
        reason: 'strategy',
        openPosition: openPosition,
        riskSettings: riskSettings,
      );

      if (signalResult.exitTrade != null) {
        trades.add(signalResult.exitTrade!);
        balance += signalResult.realizedPnL;
        equityCurve.add(balance);
      }

      openPosition = signalResult.openPosition;

      if (signalResult.entryTrade != null) {
        trades.add(signalResult.entryTrade!);
      }
    }

    if (openPosition != null) {
      final finalExit = _closePosition(
        position: openPosition,
        symbol: symbol,
        price: klines.last.close,
        timestamp: klines.last.closeTime,
        strategyName: strategy.name,
        reason: 'backtest_end',
      );
      trades.add(finalExit.trade);
      balance += finalExit.pnl;
      equityCurve.add(balance);
    }

    final summary = PerformanceSummaryCalculator.calculate(trades);

    return BacktestResult(
      symbol: symbol,
      strategyName: strategy.name,
      periodStart: klines.first.openTime,
      periodEnd: klines.last.closeTime,
      candlesProcessed: klines.length,
      startingBalance: startingBalance,
      endingBalance: balance,
      equityCurve: List<double>.unmodifiable(equityCurve),
      trades: List<Trade>.unmodifiable(trades),
      summary: summary,
    );
  }

  _SignalResult _handleSignal({
    required PositionSide desiredSide,
    required String symbol,
    required double price,
    required DateTime timestamp,
    required String strategyName,
    required String reason,
    required Position? openPosition,
    required RiskSettings riskSettings,
  }) {
    final quantity = riskSettings.tradeQuantity;
    if (quantity <= 0) {
      return const _SignalResult.empty();
    }

    if (openPosition == null) {
      final entryTrade = _buildEntryTrade(
        symbol: symbol,
        side: desiredSide,
        price: price,
        quantity: quantity,
        timestamp: timestamp,
        strategyName: strategyName,
        reason: reason,
      );
      return _SignalResult(
        openPosition: Position(
          symbol: symbol,
          side: desiredSide,
          entryPrice: price,
          quantity: quantity,
          entryTime: timestamp,
        ),
        entryTrade: entryTrade,
      );
    }

    if (openPosition.side == desiredSide) {
      return _SignalResult(openPosition: openPosition);
    }

    final close = _closePosition(
      position: openPosition,
      symbol: symbol,
      price: price,
      timestamp: timestamp,
      strategyName: strategyName,
      reason: desiredSide == PositionSide.long
          ? 'reversal_long'
          : 'reversal_short',
    );
    final entryTrade = _buildEntryTrade(
      symbol: symbol,
      side: desiredSide,
      price: price,
      quantity: quantity,
      timestamp: timestamp,
      strategyName: strategyName,
      reason: reason,
    );
    return _SignalResult(
      openPosition: Position(
        symbol: symbol,
        side: desiredSide,
        entryPrice: price,
        quantity: quantity,
        entryTime: timestamp,
      ),
      exitTrade: close.trade,
      entryTrade: entryTrade,
      realizedPnL: close.pnl,
    );
  }

  _RiskResult? _checkRisk({
    required Position position,
    required String symbol,
    required double currentPrice,
    required DateTime timestamp,
    required String strategyName,
    String? reason,
    required RiskSettings riskSettings,
  }) {
    if (riskSettings.hasStopLoss) {
      final stopLoss = position.stopLossPrice(riskSettings.stopLossPercent);
      final hitStopLoss = position.isLong
          ? currentPrice <= stopLoss
          : currentPrice >= stopLoss;
      if (hitStopLoss) {
        return _closePosition(
          position: position,
          symbol: symbol,
          price: currentPrice,
          timestamp: timestamp,
          strategyName: strategyName,
          reason: reason ?? 'stop_loss',
        );
      }
    }

    if (riskSettings.hasTakeProfit) {
      final takeProfit = position.takeProfitPrice(
        riskSettings.takeProfitPercent,
      );
      final hitTakeProfit = position.isLong
          ? currentPrice >= takeProfit
          : currentPrice <= takeProfit;
      if (hitTakeProfit) {
        return _closePosition(
          position: position,
          symbol: symbol,
          price: currentPrice,
          timestamp: timestamp,
          strategyName: strategyName,
          reason: reason ?? 'take_profit',
        );
      }
    }

    return null;
  }

  _RiskResult _closePosition({
    required Position position,
    required String symbol,
    required double price,
    required DateTime timestamp,
    required String strategyName,
    required String reason,
  }) {
    final exitSide = position.isLong ? 'SELL' : 'BUY';
    final pnl = position.isLong
        ? (price - position.entryPrice) * position.quantity
        : (position.entryPrice - price) * position.quantity;

    final trade = Trade(
      symbol: symbol,
      side: exitSide,
      price: price,
      quantity: position.quantity,
      timestamp: timestamp,
      status: 'simulated',
      strategy: strategyName,
      kind: 'EXIT',
      realizedPnl: pnl,
      reason: reason,
    );

    return _RiskResult(trade: trade, pnl: pnl);
  }

  Trade _buildEntryTrade({
    required String symbol,
    required PositionSide side,
    required double price,
    required double quantity,
    required DateTime timestamp,
    required String strategyName,
    required String reason,
  }) {
    return Trade(
      symbol: symbol,
      side: side == PositionSide.long ? 'BUY' : 'SELL',
      price: price,
      quantity: quantity,
      timestamp: timestamp,
      status: 'simulated',
      strategy: strategyName,
      kind: 'ENTRY',
      reason: reason,
    );
  }
}

class _RiskResult {
  final Trade trade;
  final double pnl;

  const _RiskResult({required this.trade, required this.pnl});
}

class _SignalResult {
  final Position? openPosition;
  final Trade? exitTrade;
  final Trade? entryTrade;
  final double realizedPnL;

  const _SignalResult({
    this.openPosition,
    this.exitTrade,
    this.entryTrade,
    this.realizedPnL = 0,
  });

  const _SignalResult.empty()
    : openPosition = null,
      exitTrade = null,
      entryTrade = null,
      realizedPnL = 0;
}
