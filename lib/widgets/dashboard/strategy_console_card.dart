import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/strategy_console_entry.dart';
import '../../providers/trading_provider.dart';
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
    final strategy = ref.watch(currentStrategyProvider);
    final isRunning = ref.watch(isBotRunningProvider(symbol));

    final plan = planAsync.valueOrNull;
    final logs = logsAsync.maybeWhen(
      data: (entries) => entries,
      orElse: () => const <StrategyConsoleEntry>[],
    );

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
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 940
                  ? 4
                  : constraints.maxWidth >= 620
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
                  label: 'Target Entry',
                  value: _formatPrice(plan?.targetEntryPrice),
                  helper: 'Planned entry',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Live Price',
                  value: _formatPrice(plan?.currentPrice),
                  helper: 'Latest candle',
                  accent: AppColors.textPrimary,
                ),
                _ConsoleMetric(
                  label: 'Leverage',
                  value: plan == null ? '--' : '${plan.leverage}x',
                  helper: 'Plan cap',
                  accent: AppColors.glowAmber,
                ),
                _ConsoleMetric(
                  label: 'Take Profit',
                  value: _formatPercent(plan?.takeProfitPercent),
                  helper: 'Profit target',
                  accent: AppColors.positive,
                ),
                _ConsoleMetric(
                  label: 'Stop Loss',
                  value: _formatPercent(plan?.stopLossPercent),
                  helper: 'Loss limit',
                  accent: AppColors.negative,
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

  static String _formatPrice(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    return value.toStringAsFixed(value >= 100 ? 2 : 6);
  }

  static String _formatPercent(double? value) {
    if (value == null || value <= 0) {
      return 'OFF';
    }
    return '${value.toStringAsFixed(2)}%';
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
