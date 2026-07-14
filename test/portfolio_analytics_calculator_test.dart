import 'package:flutter_test/flutter_test.dart';

import 'package:ifutures/models/ai_trade_outcome_snapshot.dart';
import 'package:ifutures/models/position.dart';
import 'package:ifutures/models/trade.dart';
import 'package:ifutures/services/portfolio_analytics_calculator.dart';
import 'package:ifutures/trading/strategy.dart';
import 'package:ifutures/models/manual_order.dart';

void main() {
  test('builds a portfolio analytics snapshot from account state', () {
    final trades = [
      Trade(
        symbol: 'TRIAUSDT',
        side: 'SELL',
        price: 0.0033,
        quantity: 1000,
        timestamp: DateTime(2026, 4, 3, 10, 00),
        status: 'filled',
        strategy: 'Binance Live',
        kind: 'EXIT',
        realizedPnl: 1.25,
      ),
      Trade(
        symbol: 'GALAUSDT',
        side: 'BUY',
        price: 0.019,
        quantity: 500,
        timestamp: DateTime(2026, 4, 3, 11, 00),
        status: 'filled',
        strategy: 'Binance Live',
        kind: 'EXIT',
        realizedPnl: -0.50,
      ),
    ];

    final outcomes = [
      AiTradeOutcomeSnapshot(
        symbol: 'GALAUSDT',
        positionSideLabel: 'LONG',
        realizedPnl: -0.50,
        quantity: 500,
        exitPrice: 0.019,
        closedAt: DateTime(2026, 4, 3, 11, 00),
        reason: 'stop loss',
        strategy: 'Binance Live',
        outcomeLabel: 'Stopped out',
      ),
      AiTradeOutcomeSnapshot(
        symbol: 'TRIAUSDT',
        positionSideLabel: 'SHORT',
        realizedPnl: 1.25,
        quantity: 1000,
        exitPrice: 0.0033,
        closedAt: DateTime(2026, 4, 3, 10, 00),
        reason: 'take profit',
        strategy: 'Binance Live',
        outcomeLabel: 'Take-profit win',
      ),
    ];

    final snapshot = PortfolioAnalyticsCalculator.calculate(
      selectedSymbol: 'TRIAUSDT',
      accountTrades: trades,
      openPosition: Position(
        symbol: 'TRIAUSDT',
        side: PositionSide.long,
        entryPrice: 0.0030,
        quantity: 1200,
        entryTime: DateTime(2026, 4, 3, 11, 30),
        liquidationPrice: 0.0022,
      ),
      latestPrice: 0.00325,
      walletBalance: 25.0,
      availableBalance: 20.0,
      openPositionCount: 2,
      latestPlan: StrategyTradePlan(
        strategyName: 'AI Analyst',
        signal: TradingSignal.buy,
        orderType: ManualOrderType.limit,
        currentPrice: 0.0031,
        targetEntryPrice: 0.0030,
        leverage: 10,
        takeProfitPercent: 5,
        stopLossPercent: 2,
        rationale: 'Bullish alignment with patient execution.',
        generatedAt: DateTime(2026, 4, 3, 11, 45),
        quantity: 1000,
        marketRegime: 'Trend Up',
        riskPosture: 'Balanced',
        timeframeAlignment: 'Bullish Alignment',
        executionHint: 'Lean passive near support',
        recentOutcomeLabel: 'Mixed recent outcomes',
      ),
      recentTradeOutcomes: outcomes,
      now: DateTime(2026, 4, 3, 12, 00),
    );

    expect(snapshot.trackedSymbolCount, 2);
    expect(snapshot.usedMargin, 5.0);
    expect(snapshot.marginUsagePercent, 20.0);
    expect(snapshot.currentSymbolExposure, closeTo(3.6, 0.0001));
    expect(snapshot.realizedSummary.totalTrades, 2);
    expect(snapshot.realizedSummary.totalPnL, closeTo(0.75, 0.0001));
    expect(snapshot.todaySummary.totalTrades, 2);
    expect(snapshot.outcomeBias, 'Mixed recent outcomes');
    expect(snapshot.latestPlanLabel, 'LONG | Limit');
    expect(snapshot.latestPlanAlignment, 'Bullish Alignment');
    expect(snapshot.currentPositionSideLabel, 'LONG');
    expect(snapshot.currentPositionLastPrice, closeTo(0.00325, 0.000001));
    expect(snapshot.currentPositionLiquidationPrice, closeTo(0.0022, 0.000001));
    expect(snapshot.currentPositionUnrealizedPnl, closeTo(0.30, 0.0001));
    expect(snapshot.currentPositionUnrealizedPercent, closeTo(8.3333, 0.001));
    expect(
      snapshot.currentPositionLiquidationDistancePercent,
      closeTo(32.3077, 0.001),
    );
    expect(snapshot.symbolBreakdowns, hasLength(2));
    expect(snapshot.symbolBreakdowns.first.symbol, 'TRIAUSDT');
    expect(snapshot.symbolBreakdowns.first.hasLiveExposure, isTrue);
    expect(snapshot.symbolBreakdowns.first.netPnl, closeTo(1.25, 0.0001));
  });

  test('per-symbol win rate uses exit PnL after recorded commission', () {
    final snapshot = PortfolioAnalyticsCalculator.calculate(
      selectedSymbol: 'ARIAUSDT',
      accountTrades: [
        Trade(
          symbol: 'ARIAUSDT',
          side: 'SELL',
          price: 0.10,
          quantity: 10,
          timestamp: DateTime(2026, 7, 14, 10),
          status: 'filled',
          strategy: 'Binance Demo',
          kind: 'EXIT',
          realizedPnl: 0.04,
          fee: 0.05,
        ),
      ],
      openPosition: null,
      latestPrice: 0.10,
      walletBalance: 20,
      availableBalance: 20,
      openPositionCount: 0,
      latestPlan: null,
      recentTradeOutcomes: const [],
      now: DateTime(2026, 7, 14, 11),
    );

    expect(snapshot.symbolBreakdowns.single.winningTrades, 0);
    expect(snapshot.symbolBreakdowns.single.winRate, 0);
    expect(snapshot.realizedSummary.totalPnL, closeTo(-0.01, 1e-12));
  });
}
