import 'dart:math' as math;

import '../models/kline.dart';
import '../models/manual_order.dart';
import '../models/mock_test_result.dart';
import '../models/position.dart';
import '../models/risk_settings.dart';
import '../models/trade.dart';
import '../trading/strategy.dart';
import 'performance_summary_calculator.dart';

typedef MockStrategyFactory = TradingStrategy Function(String symbol);

class MockPortfolioTestService {
  const MockPortfolioTestService();

  Future<MockPortfolioTestResult> run({
    required Map<String, List<Kline>> klinesBySymbol,
    required MockStrategyFactory strategyFactory,
    required RiskSettings riskSettings,
    required MockTestAssumptions assumptions,
    Map<String, List<MockFundingRatePoint>> fundingBySymbol = const {},
  }) async {
    _validateInputs(klinesBySymbol, riskSettings, assumptions);

    final normalized = <String, List<Kline>>{};
    for (final entry in klinesBySymbol.entries) {
      final symbol = entry.key.trim().toUpperCase();
      if (symbol.isEmpty) continue;
      normalized[symbol] = _normalizedCandles(symbol, entry.value);
    }
    if (normalized.isEmpty) {
      throw ArgumentError(
        'At least one symbol with completed candles is required.',
      );
    }

    final allocation = assumptions.startingBalanceUsdt / normalized.length;
    final symbolResults = <MockSymbolTestResult>[];
    final symbols = normalized.keys.toList()..sort();
    for (final symbol in symbols) {
      symbolResults.add(
        await _runSymbol(
          symbol: symbol,
          strategy: strategyFactory(symbol),
          riskSettings: riskSettings,
          candles: normalized[symbol]!,
          startingBalance: allocation,
          assumptions: assumptions,
          fundingRates: fundingBySymbol[symbol],
        ),
      );
    }

    final allTrades = symbolResults.expand((result) => result.trades).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final summary = PerformanceSummaryCalculator.calculate(allTrades);
    final equityCurve = _combineEquityCurves(symbolResults, allocation);
    final periodStart = symbolResults
        .map((result) => result.periodStart)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final periodEnd = symbolResults
        .map((result) => result.periodEnd)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final requiredTrades = math.max(8, symbolResults.length * 2);
    final warnings = <String>[
      'Historical exchange filters and maintenance-margin liquidation are not replayed.',
      'Each symbol receives an equal isolated share of the mock balance; this is not a live-profit prediction.',
      'On a limit-fill candle, a touched stop is conservatively assumed to occur after entry; an ambiguous same-candle take profit is not credited.',
      if (riskSettings.leverage > 1)
        'Liquidation is not modeled at ${riskSettings.leverage}x leverage, so high-leverage survival may be overstated.',
      if (assumptions.useHistoricalFunding &&
          symbolResults.any((result) => !result.usedHistoricalFunding))
        'Historical funding was unavailable for at least one symbol; the configured fixed funding stress was used there.',
      if (!assumptions.useHistoricalFunding)
        'Historical funding was disabled; the configured fixed funding stress was applied to every open position.',
    ];

    return MockPortfolioTestResult(
      assumptions: assumptions,
      symbolResults: List.unmodifiable(symbolResults),
      equityCurve: List.unmodifiable(equityCurve),
      summary: summary,
      periodStart: periodStart,
      periodEnd: periodEnd,
      requiredClosedTrades: requiredTrades,
      warnings: List.unmodifiable(warnings),
    );
  }

  Future<MockSymbolTestResult> _runSymbol({
    required String symbol,
    required TradingStrategy strategy,
    required RiskSettings riskSettings,
    required List<Kline> candles,
    required double startingBalance,
    required MockTestAssumptions assumptions,
    required List<MockFundingRatePoint>? fundingRates,
  }) async {
    final history = <Kline>[];
    final trades = <Trade>[];
    final equityCurve = <MockEquityPoint>[];
    final sortedFunding = fundingRates == null
        ? null
        : (List<MockFundingRatePoint>.of(fundingRates)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp)));

    var balance = startingBalance;
    var grossPnl = 0.0;
    var totalFees = 0.0;
    var totalFunding = 0.0;
    var slippageCost = 0.0;
    var unfilledLimits = 0;
    var consecutiveLosses = 0;
    var peakRealizedBalance = startingBalance;
    DateTime? blockedUntil;
    _MockOpenPosition? open;
    _PendingMockSignal? pending;

    for (var index = 0; index < candles.length; index++) {
      final candle = candles[index];

      if (pending != null && pending.isMarketLike) {
        final execution = _tryEnter(
          pending: pending,
          fillReference: candle.open,
          fillTime: candle.openTime,
          marketFill: true,
          currentPosition: open,
          balance: balance,
          riskSettings: riskSettings,
          assumptions: assumptions,
          fundingRates: sortedFunding,
        );
        if (execution.close != null) {
          final close = execution.close!;
          balance += close.balanceChange;
          grossPnl += close.grossPnl;
          totalFees += close.exitFee;
          totalFunding += close.fundingPayment;
          slippageCost += close.slippageCost;
          trades.add(close.trade);
          final block = _protectionAfterExit(
            exit: close,
            balance: balance,
            peakBalance: peakRealizedBalance,
            consecutiveLosses: consecutiveLosses,
            currentBlock: blockedUntil,
            riskSettings: riskSettings,
          );
          consecutiveLosses = block.consecutiveLosses;
          peakRealizedBalance = math.max(peakRealizedBalance, balance);
          blockedUntil = block.blockedUntil;
        }
        if (execution.entry != null) {
          final entry = execution.entry!;
          final entryBlocked =
              blockedUntil != null &&
              entry.trade.timestamp.isBefore(blockedUntil);
          if (!entryBlocked) {
            balance -= entry.fee;
            totalFees += entry.fee;
            slippageCost += entry.slippageCost;
            trades.add(entry.trade);
            open = entry.position;
          } else {
            open = null;
          }
        } else if (execution.close != null) {
          open = null;
        }
        pending = null;
      }

      if (open != null) {
        final riskExit = _checkIntrabarRisk(
          open: open,
          candle: candle,
          riskSettings: riskSettings,
          assumptions: assumptions,
          fundingRates: sortedFunding,
        );
        if (riskExit != null) {
          balance += riskExit.balanceChange;
          grossPnl += riskExit.grossPnl;
          totalFees += riskExit.exitFee;
          totalFunding += riskExit.fundingPayment;
          slippageCost += riskExit.slippageCost;
          trades.add(riskExit.trade);
          open = null;
          final block = _protectionAfterExit(
            exit: riskExit,
            balance: balance,
            peakBalance: peakRealizedBalance,
            consecutiveLosses: consecutiveLosses,
            currentBlock: blockedUntil,
            riskSettings: riskSettings,
          );
          consecutiveLosses = block.consecutiveLosses;
          peakRealizedBalance = math.max(peakRealizedBalance, balance);
          blockedUntil = block.blockedUntil;
        }
      }

      if (pending != null && !pending.isMarketLike) {
        final target = pending.targetPrice;
        final touched =
            target != null && candle.low <= target && candle.high >= target;
        if (touched) {
          final execution = _tryEnter(
            pending: pending,
            fillReference: target,
            fillTime: candle.closeTime,
            marketFill: false,
            currentPosition: open,
            balance: balance,
            riskSettings: riskSettings,
            assumptions: assumptions,
            fundingRates: sortedFunding,
          );
          if (execution.close != null) {
            final close = execution.close!;
            balance += close.balanceChange;
            grossPnl += close.grossPnl;
            totalFees += close.exitFee;
            totalFunding += close.fundingPayment;
            slippageCost += close.slippageCost;
            trades.add(close.trade);
            final block = _protectionAfterExit(
              exit: close,
              balance: balance,
              peakBalance: peakRealizedBalance,
              consecutiveLosses: consecutiveLosses,
              currentBlock: blockedUntil,
              riskSettings: riskSettings,
            );
            consecutiveLosses = block.consecutiveLosses;
            peakRealizedBalance = math.max(peakRealizedBalance, balance);
            blockedUntil = block.blockedUntil;
          }
          if (execution.entry != null) {
            final entry = execution.entry!;
            final entryBlocked =
                blockedUntil != null &&
                entry.trade.timestamp.isBefore(blockedUntil);
            if (!entryBlocked) {
              balance -= entry.fee;
              totalFees += entry.fee;
              trades.add(entry.trade);
              open = entry.position;
              final sameBarStop = _checkIntrabarRisk(
                open: open,
                candle: candle,
                riskSettings: riskSettings,
                assumptions: assumptions,
                fundingRates: sortedFunding,
                allowTakeProfit: false,
                stopReasonOverride: 'limit_fill_bar_stop',
              );
              if (sameBarStop != null) {
                balance += sameBarStop.balanceChange;
                grossPnl += sameBarStop.grossPnl;
                totalFees += sameBarStop.exitFee;
                totalFunding += sameBarStop.fundingPayment;
                slippageCost += sameBarStop.slippageCost;
                trades.add(sameBarStop.trade);
                open = null;
                final block = _protectionAfterExit(
                  exit: sameBarStop,
                  balance: balance,
                  peakBalance: peakRealizedBalance,
                  consecutiveLosses: consecutiveLosses,
                  currentBlock: blockedUntil,
                  riskSettings: riskSettings,
                );
                consecutiveLosses = block.consecutiveLosses;
                peakRealizedBalance = math.max(peakRealizedBalance, balance);
                blockedUntil = block.blockedUntil;
              }
            } else {
              open = null;
            }
          } else if (execution.close != null) {
            open = null;
          }
          pending = null;
        } else if (index - pending.createdAtIndex + 1 >=
            assumptions.limitOrderLifetimeBars) {
          unfilledLimits += 1;
          pending = null;
        }
      }

      equityCurve.add(
        MockEquityPoint(
          timestamp: candle.closeTime,
          equity: _markToMarketEquity(
            balance: balance,
            open: open,
            marketPrice: candle.close,
            timestamp: candle.closeTime,
            assumptions: assumptions,
            fundingRates: sortedFunding,
          ),
        ),
      );

      history.add(candle);
      final isBlocked =
          blockedUntil != null && candle.closeTime.isBefore(blockedUntil);
      if (pending == null && balance > 0 && !isBlocked) {
        final plan = await _buildPlan(
          strategy: strategy,
          symbol: symbol,
          history: history,
          riskSettings: riskSettings,
          openPosition: open?.position,
          trades: trades,
          balance: balance,
          asOf: candle.closeTime,
        );
        if (plan.signal != TradingSignal.hold) {
          pending = _PendingMockSignal(
            symbol: symbol,
            signal: plan.signal,
            plan: plan,
            createdAtIndex: index,
          );
        }
      }
    }

    if (open != null) {
      final finalCandle = candles.last;
      final close = _closePosition(
        open: open,
        rawPrice: finalCandle.close,
        timestamp: finalCandle.closeTime,
        reason: 'mock_test_end',
        marketFill: true,
        assumptions: assumptions,
        fundingRates: sortedFunding,
      );
      balance += close.balanceChange;
      grossPnl += close.grossPnl;
      totalFees += close.exitFee;
      totalFunding += close.fundingPayment;
      slippageCost += close.slippageCost;
      trades.add(close.trade);
      equityCurve.add(
        MockEquityPoint(timestamp: finalCandle.closeTime, equity: balance),
      );
    }

    final summary = PerformanceSummaryCalculator.calculate(trades);
    return MockSymbolTestResult(
      symbol: symbol,
      strategyName: strategy.name,
      periodStart: candles.first.openTime,
      periodEnd: candles.last.closeTime,
      candlesProcessed: candles.length,
      startingBalance: startingBalance,
      endingBalance: balance,
      grossPnl: grossPnl,
      totalFees: totalFees,
      totalFunding: totalFunding,
      estimatedSlippageCost: slippageCost,
      unfilledLimitSignals: unfilledLimits,
      usedHistoricalFunding:
          assumptions.useHistoricalFunding && sortedFunding != null,
      equityCurve: List.unmodifiable(equityCurve),
      trades: List.unmodifiable(trades),
      summary: summary,
    );
  }

  Future<StrategyTradePlan> _buildPlan({
    required TradingStrategy strategy,
    required String symbol,
    required List<Kline> history,
    required RiskSettings riskSettings,
    required Position? openPosition,
    required List<Trade> trades,
    required double balance,
    required DateTime asOf,
  }) async {
    if (strategy case final TradePlanningStrategy planningStrategy) {
      return planningStrategy.buildTradePlan(
        List.unmodifiable(history),
        symbol: symbol,
        riskSettings: riskSettings,
        context: StrategyAnalysisContext(
          asOf: asOf,
          openPosition: openPosition,
          symbolTrades: List.unmodifiable(trades),
          accountTrades: List.unmodifiable(trades),
          walletBalance: balance,
          availableBalance: balance,
          openPositionCount: openPosition == null ? 0 : 1,
        ),
      );
    }
    final signal = await strategy.evaluate(List.unmodifiable(history));
    return StrategyTradePlan(
      strategyName: strategy.name,
      signal: signal,
      orderType: signal == TradingSignal.hold ? null : ManualOrderType.market,
      currentPrice: history.last.close,
      targetEntryPrice: history.last.close,
      leverage: riskSettings.leverage,
      takeProfitPercent: riskSettings.takeProfitPercent,
      stopLossPercent: riskSettings.stopLossPercent,
      quantity: riskSettings.resolveQuantity(history.last.close),
      rationale: 'Deterministic mock-test signal.',
      generatedAt: asOf,
    );
  }

  _EntryAttempt _tryEnter({
    required _PendingMockSignal pending,
    required double fillReference,
    required DateTime fillTime,
    required bool marketFill,
    required _MockOpenPosition? currentPosition,
    required double balance,
    required RiskSettings riskSettings,
    required MockTestAssumptions assumptions,
    required List<MockFundingRatePoint>? fundingRates,
  }) {
    final desiredSide = pending.signal == TradingSignal.buy
        ? PositionSide.long
        : PositionSide.short;
    if (currentPosition?.position.side == desiredSide) {
      return const _EntryAttempt();
    }

    _CloseExecution? close;
    var availableBalance = balance;
    if (currentPosition != null) {
      close = _closePosition(
        open: currentPosition,
        rawPrice: fillReference,
        timestamp: fillTime,
        reason: desiredSide == PositionSide.long
            ? 'reversal_long'
            : 'reversal_short',
        marketFill: true,
        assumptions: assumptions,
        fundingRates: fundingRates,
      );
      availableBalance += close.balanceChange;
    }

    final entryPrice = marketFill
        ? _adverseFillPrice(
            fillReference,
            isBuy: desiredSide == PositionSide.long,
            assumptions: assumptions,
          )
        : fillReference;
    final quantity = _entryQuantity(
      requested: pending.plan.quantity,
      entryPrice: entryPrice,
      balance: availableBalance,
      riskSettings: riskSettings,
      assumptions: assumptions,
    );
    if (quantity == null) return _EntryAttempt(close: close);

    final fee = entryPrice * quantity * assumptions.feeRatePerSide;
    final slippage = (entryPrice - fillReference).abs() * quantity;
    final trade = Trade(
      symbol: currentPosition?.position.symbol ?? pending.symbol,
      side: desiredSide == PositionSide.long ? 'BUY' : 'SELL',
      price: entryPrice,
      quantity: quantity,
      timestamp: fillTime,
      status: 'simulated',
      fee: fee,
      strategy: pending.plan.strategyName,
      kind: 'ENTRY',
      orderType: pending.plan.orderType?.name,
      requestedPrice: pending.targetPrice,
      reason: 'next_bar_signal',
    );
    final symbol = trade.symbol;
    return _EntryAttempt(
      close: close,
      entry: _EntryExecution(
        position: _MockOpenPosition(
          position: Position(
            symbol: symbol,
            side: desiredSide,
            entryPrice: entryPrice,
            quantity: quantity,
            entryTime: fillTime,
          ),
          plan: pending.plan,
          entryFee: fee,
        ),
        trade: trade,
        fee: fee,
        slippageCost: slippage,
      ),
    );
  }

  double? _entryQuantity({
    required double? requested,
    required double entryPrice,
    required double balance,
    required RiskSettings riskSettings,
    required MockTestAssumptions assumptions,
  }) {
    if (!entryPrice.isFinite || entryPrice <= 0 || balance <= 0) return null;
    final leverage = riskSettings.leverage;
    if (leverage <= 0) return null;
    final configuredMargin = riskSettings.investmentUsdt ?? balance;
    final marginBudget = math.min(configuredMargin, balance);
    final maxNotionalByBudget = marginBudget * leverage;
    final cashCostPerNotional = (1 / leverage) + assumptions.feeRatePerSide;
    final maxNotionalByCash = cashCostPerNotional <= 0
        ? maxNotionalByBudget
        : balance / cashCostPerNotional;
    final maxQuantity =
        math.min(maxNotionalByBudget, maxNotionalByCash) / entryPrice;
    final configuredQuantity =
        requested ?? riskSettings.resolveQuantity(entryPrice);
    final quantity = configuredQuantity == null
        ? maxQuantity
        : math.min(configuredQuantity, maxQuantity);
    return quantity.isFinite && quantity > 0 ? quantity : null;
  }

  _CloseExecution? _checkIntrabarRisk({
    required _MockOpenPosition open,
    required Kline candle,
    required RiskSettings riskSettings,
    required MockTestAssumptions assumptions,
    required List<MockFundingRatePoint>? fundingRates,
    bool allowTakeProfit = true,
    String? stopReasonOverride,
  }) {
    final position = open.position;
    final stopPercent = riskSettings.resolveStopLossPercent(
      position.entryPrice,
      quantity: position.quantity,
      fallbackPercent: open.plan.stopLossPercent,
    );
    final takePercent = riskSettings.resolveTakeProfitPercent(
      position.entryPrice,
      quantity: position.quantity,
      fallbackPercent: open.plan.takeProfitPercent,
    );
    final stopPrice = stopPercent > 0
        ? position.stopLossPrice(stopPercent)
        : null;
    final takePrice = takePercent > 0
        ? position.takeProfitPrice(takePercent)
        : null;
    final hitStop =
        stopPrice != null &&
        (position.isLong ? candle.low <= stopPrice : candle.high >= stopPrice);
    final hitTake =
        allowTakeProfit &&
        takePrice != null &&
        (position.isLong ? candle.high >= takePrice : candle.low <= takePrice);
    if (!hitStop && !hitTake) return null;

    // OHLC data cannot reveal which trigger happened first. Stop-first is the
    // conservative policy when both prices fall inside the same candle.
    final useStop = hitStop;
    final trigger = useStop ? stopPrice : takePrice;
    if (trigger == null) return null;
    final rawPrice = useStop
        ? position.isLong
              ? math.min(trigger, candle.open)
              : math.max(trigger, candle.open)
        : trigger;
    return _closePosition(
      open: open,
      rawPrice: rawPrice,
      timestamp: candle.closeTime,
      reason: hitStop && hitTake
          ? 'stop_first_same_bar'
          : useStop
          ? (stopReasonOverride ?? 'stop_loss')
          : 'take_profit',
      marketFill: true,
      assumptions: assumptions,
      fundingRates: fundingRates,
    );
  }

  _CloseExecution _closePosition({
    required _MockOpenPosition open,
    required double rawPrice,
    required DateTime timestamp,
    required String reason,
    required bool marketFill,
    required MockTestAssumptions assumptions,
    required List<MockFundingRatePoint>? fundingRates,
  }) {
    final position = open.position;
    final isExitBuy = !position.isLong;
    final exitPrice = marketFill
        ? _adverseFillPrice(
            rawPrice,
            isBuy: isExitBuy,
            assumptions: assumptions,
          )
        : rawPrice;
    final grossPnl = position.isLong
        ? (exitPrice - position.entryPrice) * position.quantity
        : (position.entryPrice - exitPrice) * position.quantity;
    final exitFee = exitPrice * position.quantity * assumptions.feeRatePerSide;
    final funding = _fundingPayment(
      open: open,
      exitTime: timestamp,
      assumptions: assumptions,
      fundingRates: fundingRates,
    );
    final slippage = (exitPrice - rawPrice).abs() * position.quantity;
    final trade = Trade(
      symbol: position.symbol,
      side: position.isLong ? 'SELL' : 'BUY',
      price: exitPrice,
      quantity: position.quantity,
      timestamp: timestamp,
      status: 'simulated',
      fee: open.entryFee + exitFee,
      strategy: open.plan.strategyName,
      kind: 'EXIT',
      realizedPnl: grossPnl - funding,
      orderType: marketFill ? ManualOrderType.market.name : null,
      requestedPrice: rawPrice,
      reason: reason,
    );
    return _CloseExecution(
      trade: trade,
      grossPnl: grossPnl,
      exitFee: exitFee,
      fundingPayment: funding,
      slippageCost: slippage,
      balanceChange: grossPnl - exitFee - funding,
    );
  }

  double _fundingPayment({
    required _MockOpenPosition open,
    required DateTime exitTime,
    required MockTestAssumptions assumptions,
    required List<MockFundingRatePoint>? fundingRates,
  }) {
    final position = open.position;
    final notional = position.entryPrice * position.quantity;
    if (assumptions.useHistoricalFunding && fundingRates != null) {
      var payment = 0.0;
      for (final point in fundingRates) {
        if (point.timestamp.isAfter(position.entryTime) &&
            !point.timestamp.isAfter(exitTime)) {
          payment += notional * point.rate * (position.isLong ? 1 : -1);
        }
      }
      return payment;
    }
    final heldHours = math.max(
      0.0,
      exitTime.difference(position.entryTime).inMilliseconds / 3600000,
    );
    return notional * assumptions.fundingRatePer8Hours * (heldHours / 8);
  }

  double _markToMarketEquity({
    required double balance,
    required _MockOpenPosition? open,
    required double marketPrice,
    required DateTime timestamp,
    required MockTestAssumptions assumptions,
    required List<MockFundingRatePoint>? fundingRates,
  }) {
    if (open == null) return balance;
    final position = open.position;
    final exitPrice = _adverseFillPrice(
      marketPrice,
      isBuy: !position.isLong,
      assumptions: assumptions,
    );
    final gross = position.isLong
        ? (exitPrice - position.entryPrice) * position.quantity
        : (position.entryPrice - exitPrice) * position.quantity;
    final exitFee = exitPrice * position.quantity * assumptions.feeRatePerSide;
    final funding = _fundingPayment(
      open: open,
      exitTime: timestamp,
      assumptions: assumptions,
      fundingRates: fundingRates,
    );
    return balance + gross - exitFee - funding;
  }

  double _adverseFillPrice(
    double reference, {
    required bool isBuy,
    required MockTestAssumptions assumptions,
  }) {
    final rate = assumptions.slippageRatePerMarketFill;
    return isBuy ? reference * (1 + rate) : reference * (1 - rate);
  }

  _ProtectionAfterExit _protectionAfterExit({
    required _CloseExecution exit,
    required double balance,
    required double peakBalance,
    required int consecutiveLosses,
    required DateTime? currentBlock,
    required RiskSettings riskSettings,
  }) {
    final netPnl = PerformanceSummaryCalculator.realizedPnlAfterFee(exit.trade);
    final nextLosses = netPnl < 0 ? consecutiveLosses + 1 : 0;
    DateTime? blockedUntil = currentBlock;

    void extend(Duration duration) {
      if (duration <= Duration.zero) return;
      final candidate = exit.trade.timestamp.add(duration);
      if (blockedUntil == null || candidate.isAfter(blockedUntil!)) {
        blockedUntil = candidate;
      }
    }

    extend(Duration(minutes: riskSettings.cooldownMinutes));
    if (riskSettings.hasLossStreakProtection &&
        nextLosses >= riskSettings.maxConsecutiveLosses) {
      extend(Duration(minutes: riskSettings.protectionPauseMinutes));
    }
    final drawdownPercent = peakBalance <= 0
        ? 0.0
        : ((peakBalance - balance) / peakBalance) * 100;
    if (riskSettings.hasDrawdownProtection &&
        drawdownPercent >= riskSettings.maxDrawdownPercent) {
      extend(Duration(minutes: riskSettings.protectionPauseMinutes));
    }
    return _ProtectionAfterExit(
      consecutiveLosses: nextLosses,
      blockedUntil: blockedUntil,
    );
  }

  List<MockEquityPoint> _combineEquityCurves(
    List<MockSymbolTestResult> results,
    double allocation,
  ) {
    final updates = <DateTime, Map<String, double>>{};
    for (final result in results) {
      for (final point in result.equityCurve) {
        updates.putIfAbsent(point.timestamp, () => {})[result.symbol] =
            point.equity;
      }
    }
    final timestamps = updates.keys.toList()..sort();
    final latest = <String, double>{
      for (final result in results) result.symbol: allocation,
    };
    final combined = <MockEquityPoint>[];
    for (final timestamp in timestamps) {
      latest.addAll(updates[timestamp]!);
      combined.add(
        MockEquityPoint(
          timestamp: timestamp,
          equity: latest.values.fold(0.0, (sum, value) => sum + value),
        ),
      );
    }
    return combined;
  }

  List<Kline> _normalizedCandles(String symbol, List<Kline> candles) {
    final sorted = List<Kline>.of(candles)
      ..sort((a, b) => a.openTime.compareTo(b.openTime));
    final byOpenTime = <DateTime, Kline>{};
    for (final candle in sorted) {
      final values = [
        candle.open,
        candle.high,
        candle.low,
        candle.close,
        candle.volume,
      ];
      if (values.any((value) => !value.isFinite) ||
          candle.open <= 0 ||
          candle.high < candle.low ||
          candle.high < math.max(candle.open, candle.close) ||
          candle.low > math.min(candle.open, candle.close) ||
          !candle.closeTime.isAfter(candle.openTime)) {
        throw ArgumentError('Invalid historical candle for $symbol.');
      }
      byOpenTime[candle.openTime] = candle;
    }
    final normalized = byOpenTime.values.toList()
      ..sort((a, b) => a.openTime.compareTo(b.openTime));
    if (normalized.length < 2) {
      throw ArgumentError('$symbol needs at least two completed candles.');
    }
    return normalized;
  }

  void _validateInputs(
    Map<String, List<Kline>> klinesBySymbol,
    RiskSettings riskSettings,
    MockTestAssumptions assumptions,
  ) {
    if (klinesBySymbol.isEmpty) {
      throw ArgumentError('Select at least one symbol for the mock test.');
    }
    final numbers = [
      assumptions.startingBalanceUsdt,
      assumptions.feePercentPerSide,
      assumptions.slippageBpsPerMarketFill,
      assumptions.fundingPercentPer8Hours,
    ];
    if (numbers.any((value) => !value.isFinite) ||
        assumptions.startingBalanceUsdt <= 0 ||
        assumptions.feePercentPerSide < 0 ||
        assumptions.feePercentPerSide > 10 ||
        assumptions.slippageBpsPerMarketFill < 0 ||
        assumptions.slippageBpsPerMarketFill > 1000 ||
        assumptions.fundingPercentPer8Hours < 0 ||
        assumptions.fundingPercentPer8Hours > 10 ||
        assumptions.limitOrderLifetimeBars < 1 ||
        riskSettings.leverage < 1) {
      throw ArgumentError('Mock-test assumptions are outside safe bounds.');
    }
  }
}

class _PendingMockSignal {
  final String symbol;
  final TradingSignal signal;
  final StrategyTradePlan plan;
  final int createdAtIndex;

  const _PendingMockSignal({
    required this.symbol,
    required this.signal,
    required this.plan,
    required this.createdAtIndex,
  });

  bool get isMarketLike =>
      plan.orderType == null || plan.orderType == ManualOrderType.market;

  double? get targetPrice => plan.targetEntryPrice;
}

class _MockOpenPosition {
  final Position position;
  final StrategyTradePlan plan;
  final double entryFee;

  const _MockOpenPosition({
    required this.position,
    required this.plan,
    required this.entryFee,
  });
}

class _EntryExecution {
  final _MockOpenPosition position;
  final Trade trade;
  final double fee;
  final double slippageCost;

  const _EntryExecution({
    required this.position,
    required this.trade,
    required this.fee,
    required this.slippageCost,
  });
}

class _EntryAttempt {
  final _CloseExecution? close;
  final _EntryExecution? entry;

  const _EntryAttempt({this.close, this.entry});
}

class _CloseExecution {
  final Trade trade;
  final double grossPnl;
  final double exitFee;
  final double fundingPayment;
  final double slippageCost;
  final double balanceChange;

  const _CloseExecution({
    required this.trade,
    required this.grossPnl,
    required this.exitFee,
    required this.fundingPayment,
    required this.slippageCost,
    required this.balanceChange,
  });
}

class _ProtectionAfterExit {
  final int consecutiveLosses;
  final DateTime? blockedUntil;

  const _ProtectionAfterExit({
    required this.consecutiveLosses,
    required this.blockedUntil,
  });
}
