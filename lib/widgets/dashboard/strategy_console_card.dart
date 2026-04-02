import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/ai_timeframe_snapshot.dart';
import '../../models/position.dart';
import '../../models/strategy_console_entry.dart';
import '../../models/trade.dart';
import '../../providers/trading_provider.dart';
import '../../services/performance_summary_calculator.dart';
import '../../theme/app_theme.dart';
import '../../trading/manual_strategy.dart';
import '../../trading/strategy.dart';
import '../common/app_panel.dart';
import '../common/status_pill.dart';

class StrategyConsoleCard extends ConsumerWidget {
  final String symbol;

  const StrategyConsoleCard({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(decisionPlanStreamProvider(symbol));
    final logsAsync = ref.watch(consoleLogStreamProvider(symbol));
    final accountTradesAsync = ref.watch(accountTradeStreamProvider(symbol));
    final positionAsync = ref.watch(positionStreamProvider(symbol));
    final riskAsync = ref.watch(riskSettingsProvider);
    final tickerAsync = ref.watch(tickerStreamProvider(symbol));
    final engineAsync = ref.watch(tradingEngineProvider(symbol));
    ref.watch(binanceAccountStatusProvider(symbol));
    final strategy = ref.watch(currentStrategyProvider);
    final isRunning = ref.watch(isBotRunningProvider(symbol));

    final plan = planAsync.valueOrNull;
    final position = positionAsync.valueOrNull;
    final risk = riskAsync.valueOrNull;
    final logs = logsAsync.maybeWhen(
      data: (entries) => entries,
      orElse: () => const <StrategyConsoleEntry>[],
    );
    final accountTrades = accountTradesAsync.maybeWhen(
      data: (entries) => entries,
      orElse: () => const <Trade>[],
    );
    final accountSummary = PerformanceSummaryCalculator.calculate(
      accountTrades,
    );
    final engine = engineAsync.valueOrNull;
    final livePrice = tickerAsync.maybeWhen(
      data: (data) => double.tryParse(data['c']?.toString() ?? ''),
      orElse: () => plan?.currentPrice,
    );
    final positionNotional = position == null
        ? null
        : position.entryPrice * position.quantity;
    final positionMargin = positionNotional == null
        ? null
        : positionNotional /
              ((risk?.leverage ?? plan?.leverage ?? 1).clamp(1, 125));
    final unrealizedPnl = _computePositionPnl(position, livePrice);
    final roePercent =
        unrealizedPnl == null || positionMargin == null || positionMargin == 0
        ? null
        : (unrealizedPnl / positionMargin) * 100;
    final positionLabel = position == null
        ? 'NONE'
        : '${position.isLong ? 'LONG' : 'SHORT'} ${_formatQuantity(position.quantity)}';
    final oneMinute = _timeframeSnapshot(plan, '1m');
    final fiveMinute = _timeframeSnapshot(plan, '5m');
    final fifteenMinute = _timeframeSnapshot(plan, '15m');

    return AppPanel(
      accent: _executionColor(strategy, isRunning),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.terminal,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Strategy Terminal',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Run analysis now',
                onPressed: () async {
                  final engine = await ref.read(
                    tradingEngineProvider(symbol).future,
                  );
                  await engine.refreshStrategyPlan();
                },
                icon: const Icon(Icons.refresh),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strategy is ManualStrategy
                ? 'Manual mode is active. The terminal still shows market sync and strategy refresh activity.'
                : 'AI and ALGO now publish the chosen side, order type, and live activity log here.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label:
                    'Source: ${plan?.strategyName ?? strategy?.name ?? 'Strategy'}',
                color: AppColors.glowCyan,
              ),
              StatusPill(
                label: plan?.summaryLabel ?? 'Waiting',
                color: _signalColor(plan?.signal),
              ),
              StatusPill(
                label: _executionLabel(strategy, isRunning),
                color: _executionColor(strategy, isRunning),
              ),
              if (plan?.confidence != null)
                StatusPill(
                  label:
                      'Confidence ${(plan!.confidence! * 100).toStringAsFixed(0)}%',
                  color: AppColors.glowAmber,
                ),
              if (plan?.timeframeAlignment?.trim().isNotEmpty == true)
                StatusPill(
                  label: 'Alignment: ${plan!.timeframeAlignment!}',
                  color: AppColors.textPrimary,
                ),
              if (plan?.executionHint?.trim().isNotEmpty == true)
                StatusPill(
                  label: 'Book: ${plan!.executionHint!}',
                  color: AppColors.glowAmber,
                ),
              if (plan?.marketRegime?.trim().isNotEmpty == true)
                StatusPill(
                  label: 'Regime: ${plan!.marketRegime!}',
                  color: AppColors.textPrimary,
                ),
              if (plan?.riskPosture?.trim().isNotEmpty == true)
                StatusPill(
                  label: 'Risk: ${plan!.riskPosture!}',
                  color: AppColors.glowAmber,
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1160
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 4
                  : constraints.maxWidth >= 520
                  ? 2
                  : 1;
              final spacing = columns == 1 ? 0.0 : 12.0;
              final tileWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              final metrics = [
                _ConsoleMetric(
                  label: 'Action',
                  value: plan?.actionLabel ?? 'WAIT',
                  helper: 'Latest side',
                  accent: _signalColor(plan?.signal),
                ),
                _ConsoleMetric(
                  label: 'Order Type',
                  value: plan?.orderTypeLabel.toUpperCase() ?? 'WATCH',
                  helper: 'Execution style',
                  accent: AppColors.glowCyan,
                ),
                _ConsoleMetric(
                  label: 'Plan Qty',
                  value: _formatQuantity(plan?.quantity),
                  helper: 'Planned size',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Size Bias',
                  value: plan?.sizeFraction == null
                      ? '--'
                      : '${(plan!.sizeFraction! * 100).toStringAsFixed(0)}%',
                  helper: 'AI fraction of max size',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Leverage',
                  value: plan == null ? '--' : '${plan.leverage}x',
                  helper: 'Plan cap',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Wallet',
                  value: _formatUsdt(engine?.walletBalance),
                  helper: 'Binance wallet',
                  accent: AppColors.glowCyan,
                ),
                _ConsoleMetric(
                  label: 'Available',
                  value: _formatUsdt(engine?.availableBalance),
                  helper: 'Free margin',
                  accent: AppColors.positive,
                ),
                _ConsoleMetric(
                  label: 'Open Markets',
                  value: engine?.openPositionCount?.toString() ?? '--',
                  helper: 'Tracked futures',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Target Entry',
                  value: _formatPrice(plan?.effectiveEntryPrice),
                  helper: 'Planned entry',
                  accent: AppColors.textPrimary,
                ),
                _ConsoleMetric(
                  label: 'Planned Exposure',
                  value: _formatUsdt(plan?.plannedNotional),
                  helper: 'Qty x entry',
                  accent: AppColors.textPrimary,
                ),
                _ConsoleMetric(
                  label: 'Est. Margin',
                  value: _formatUsdt(plan?.estimatedMarginRequired),
                  helper: 'Exposure / leverage',
                  accent: AppColors.glowCyan,
                ),
                _ConsoleMetric(
                  label: 'Target PnL',
                  value: _formatSignedUsdt(plan?.projectedProfitAtTarget),
                  helper: plan?.takeProfitPrice == null
                      ? 'Take profit off'
                      : 'TP @ ${_formatPrice(plan?.takeProfitPrice)}',
                  accent: AppColors.positive,
                ),
                _ConsoleMetric(
                  label: 'Max Loss',
                  value: plan?.projectedLossAtStop == null
                      ? '--'
                      : '-${_formatUsdt(plan?.projectedLossAtStop)}',
                  helper: plan?.stopLossPrice == null
                      ? 'Stop loss off'
                      : 'SL @ ${_formatPrice(plan?.stopLossPrice)}',
                  accent: AppColors.negative,
                ),
                _ConsoleMetric(
                  label: 'Current Position',
                  value: positionLabel,
                  helper: position == null ? 'No live exposure' : 'Open size',
                  accent: position == null
                      ? AppColors.textSecondary
                      : (position.isLong
                            ? AppColors.positive
                            : AppColors.negative),
                ),
                _ConsoleMetric(
                  label: 'Position Exposure',
                  value: _formatUsdt(positionNotional),
                  helper: position == null ? 'Entry x qty' : 'At entry price',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Unrealized PnL',
                  value: _formatSignedUsdt(unrealizedPnl),
                  helper: roePercent == null
                      ? 'Waiting for price move'
                      : 'ROE ${roePercent.toStringAsFixed(2)}%',
                  accent: unrealizedPnl == null
                      ? AppColors.textSecondary
                      : (unrealizedPnl >= 0
                            ? AppColors.positive
                            : AppColors.negative),
                ),
                _ConsoleMetric(
                  label: 'Est. Position Margin',
                  value: _formatUsdt(positionMargin),
                  helper: 'Approximate live margin',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Tracked PnL',
                  value: _formatSignedUsdt(accountSummary.totalPnL),
                  helper: accountSummary.totalTrades == 0
                      ? 'No closed fills yet'
                      : 'Win rate ${accountSummary.winRate.toStringAsFixed(0)}%',
                  accent: accountSummary.totalPnL >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
                _ConsoleMetric(
                  label: 'Trade Review',
                  value: plan?.tradeReviewState ?? '--',
                  helper: 'Recent realized performance',
                  accent: switch (plan?.tradeReviewState) {
                    'Hot' => AppColors.positive,
                    'Cold' => AppColors.negative,
                    'Unproven' => AppColors.textSecondary,
                    _ => AppColors.glowCyan,
                  },
                ),
                _ConsoleMetric(
                  label: 'Spread',
                  value: plan?.spreadPercent == null
                      ? '--'
                      : '${plan!.spreadPercent!.toStringAsFixed(4)}%',
                  helper: 'Best bid / ask gap',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Book Imbalance',
                  value: plan?.orderBookImbalancePercent == null
                      ? '--'
                      : '${plan!.orderBookImbalancePercent!.toStringAsFixed(1)}%',
                  helper: 'Bid vs ask depth',
                  accent: plan?.orderBookImbalancePercent == null
                      ? AppColors.textSecondary
                      : ((plan!.orderBookImbalancePercent!) >= 0
                            ? AppColors.positive
                            : AppColors.negative),
                ),
                _ConsoleMetric(
                  label: 'Buy Slip',
                  value: plan?.estimatedBuySlippagePercent == null
                      ? '--'
                      : '${plan!.estimatedBuySlippagePercent!.toStringAsFixed(4)}%',
                  helper: 'Est. market buy impact',
                  accent: AppColors.glowCyan,
                ),
                _ConsoleMetric(
                  label: 'Sell Slip',
                  value: plan?.estimatedSellSlippagePercent == null
                      ? '--'
                      : '${plan!.estimatedSellSlippagePercent!.toStringAsFixed(4)}%',
                  helper: 'Est. market sell impact',
                  accent: AppColors.glowCyan,
                ),
                if (oneMinute != null)
                  _ConsoleMetric(
                    label: '1m Context',
                    value: oneMinute.regime,
                    helper:
                        '${oneMinute.shortMomentumPercent.toStringAsFixed(2)}% short move',
                    accent: _timeframeAccent(oneMinute.regime),
                  ),
                if (fiveMinute != null)
                  _ConsoleMetric(
                    label: '5m Context',
                    value: fiveMinute.regime,
                    helper:
                        '${fiveMinute.mediumMomentumPercent.toStringAsFixed(2)}% medium move',
                    accent: _timeframeAccent(fiveMinute.regime),
                  ),
                if (fifteenMinute != null)
                  _ConsoleMetric(
                    label: '15m Context',
                    value: fifteenMinute.regime,
                    helper:
                        'Range ${fifteenMinute.rangePositionPercent.toStringAsFixed(0)}%',
                    accent: _timeframeAccent(fifteenMinute.regime),
                  ),
                _ConsoleMetric(
                  label: 'Live Price',
                  value: _formatPrice(livePrice),
                  helper: 'Latest candle',
                  accent: AppColors.textPrimary,
                ),
                _ConsoleMetric(
                  label: 'Updated',
                  value: plan == null
                      ? '--'
                      : DateFormat('HH:mm:ss').format(plan.generatedAt),
                  helper: 'Latest plan',
                  accent: AppColors.textSecondary,
                ),
              ];

              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: [
                  for (final metric in metrics)
                    SizedBox(width: tileWidth, child: metric),
                ],
              );
            },
          ),
          if (plan?.rationale?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _signalColor(plan?.signal).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Latest Reasoning',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan!.rationale,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.dns_outlined,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Terminal Output',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${logs.length} events',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 120,
                    maxHeight: 220,
                  ),
                  child: logs.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '[waiting] No strategy activity yet. Use the refresh button or switch to AI/ALGO.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: logs.length > 10 ? 10 : logs.length,
                          itemBuilder: (context, index) {
                            final entry =
                                logs[logs.length -
                                    (logs.length > 10 ? 10 : logs.length) +
                                    index];
                            return _LogLine(entry: entry);
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _executionLabel(TradingStrategy? strategy, bool isRunning) {
    if (strategy is ManualStrategy) {
      return 'Manual control';
    }
    if (isRunning) {
      return 'Auto execution armed';
    }
    return 'Analysis only';
  }

  static Color _executionColor(TradingStrategy? strategy, bool isRunning) {
    if (strategy is ManualStrategy) {
      return AppColors.glowAmber;
    }
    if (isRunning) {
      return AppColors.positive;
    }
    return AppColors.glowCyan;
  }

  static Color _signalColor(TradingSignal? signal) {
    return switch (signal) {
      TradingSignal.buy => AppColors.positive,
      TradingSignal.sell => AppColors.negative,
      TradingSignal.hold => AppColors.glowAmber,
      null => AppColors.textSecondary,
    };
  }

  static AiTimeframeSnapshot? _timeframeSnapshot(
    StrategyTradePlan? plan,
    String label,
  ) {
    if (plan == null) {
      return null;
    }

    for (final snapshot in plan.timeframeSnapshots) {
      if (snapshot.label == label) {
        return snapshot;
      }
    }
    return null;
  }

  static Color _timeframeAccent(String regime) {
    if (regime.startsWith('Trend Up') || regime == 'Pullback') {
      return AppColors.positive;
    }
    if (regime.startsWith('Trend Down') || regime == 'Relief Bounce') {
      return AppColors.negative;
    }
    if (regime == 'Squeeze' || regime == 'Range') {
      return AppColors.glowAmber;
    }
    return AppColors.glowCyan;
  }

  static String _formatPrice(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    return value.toStringAsFixed(value >= 100 ? 2 : 6);
  }

  static String _formatQuantity(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    final digits = value >= 1000
        ? 2
        : value >= 1
        ? 4
        : 6;
    return value.toStringAsFixed(digits);
  }

  static String _formatUsdt(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    final digits = value >= 100
        ? 2
        : value >= 1
        ? 3
        : 6;
    return '${value.toStringAsFixed(digits)} USDT';
  }

  static String _formatSignedUsdt(double? value) {
    if (value == null) {
      return '--';
    }
    if (value == 0) {
      return '0.00 USDT';
    }
    final prefix = value > 0 ? '+' : '-';
    return '$prefix${_formatUsdt(value.abs())}';
  }

  static double? _computePositionPnl(Position? position, double? livePrice) {
    if (position == null || livePrice == null) {
      return null;
    }

    return position.isLong
        ? (livePrice - position.entryPrice) * position.quantity
        : (position.entryPrice - livePrice) * position.quantity;
  }
}

class _ConsoleMetric extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color accent;

  const _ConsoleMetric({
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: tabularFigures(
              TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final StrategyConsoleEntry entry;

  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      StrategyConsoleLevel.success => AppColors.positive,
      StrategyConsoleLevel.warning => AppColors.glowAmber,
      StrategyConsoleLevel.error => AppColors.negative,
      StrategyConsoleLevel.info => AppColors.glowCyan,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '[${DateFormat('HH:mm:ss').format(entry.timestamp)}] ',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        Expanded(
          child: Text(
            entry.message,
            style: TextStyle(
              color: color,
              fontSize: 11,
              height: 1.4,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
