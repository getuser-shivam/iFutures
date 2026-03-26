import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final strategy = ref.watch(currentStrategyProvider);
    final isRunning = ref.watch(isBotRunningProvider(symbol));

    return AppPanel(
      accent: _executionColor(strategy, isRunning),
      child: planAsync.when(
        loading: () => _ConsoleBody(
          title: strategy?.name ?? 'Strategy',
          summary: 'Waiting for candles',
          executionLabel: _executionLabel(strategy, isRunning),
          executionColor: _executionColor(strategy, isRunning),
          generatedAtLabel: 'Syncing',
          currentPrice: null,
          targetEntryPrice: null,
          leverage: null,
          takeProfitPercent: null,
          stopLossPercent: null,
          confidence: null,
          rationale:
              'The console is warming up. As soon as candles load, AI or ALGO will publish its latest plan here.',
          signal: null,
          orderTypeLabel: 'Watch',
        ),
        error: (error, _) => _ConsoleError(error: error),
        data: (plan) => _ConsoleBody(
          title: plan?.strategyName ?? strategy?.name ?? 'Strategy',
          summary: plan?.summaryLabel ?? 'Waiting for candles',
          executionLabel: _executionLabel(strategy, isRunning),
          executionColor: _executionColor(strategy, isRunning),
          generatedAtLabel: plan == null
              ? 'Waiting'
              : DateFormat('HH:mm:ss').format(plan.generatedAt),
          currentPrice: plan?.currentPrice,
          targetEntryPrice: plan?.targetEntryPrice,
          leverage: plan?.leverage,
          takeProfitPercent: plan?.takeProfitPercent,
          stopLossPercent: plan?.stopLossPercent,
          confidence: plan?.confidence,
          rationale:
              plan?.rationale ??
              'The console is waiting for the first completed market read.',
          signal: plan?.signal,
          orderTypeLabel: plan?.orderTypeLabel ?? 'Watch',
          longBiasPrice: plan?.longBiasPrice,
          shortBiasPrice: plan?.shortBiasPrice,
        ),
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
    return 'Suggestion only';
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
}

class _ConsoleBody extends StatelessWidget {
  final String title;
  final String summary;
  final String executionLabel;
  final Color executionColor;
  final String generatedAtLabel;
  final double? currentPrice;
  final double? targetEntryPrice;
  final int? leverage;
  final double? takeProfitPercent;
  final double? stopLossPercent;
  final double? confidence;
  final String rationale;
  final TradingSignal? signal;
  final String orderTypeLabel;
  final double? longBiasPrice;
  final double? shortBiasPrice;

  const _ConsoleBody({
    required this.title,
    required this.summary,
    required this.executionLabel,
    required this.executionColor,
    required this.generatedAtLabel,
    required this.currentPrice,
    required this.targetEntryPrice,
    required this.leverage,
    required this.takeProfitPercent,
    required this.stopLossPercent,
    required this.confidence,
    required this.rationale,
    required this.signal,
    required this.orderTypeLabel,
    this.longBiasPrice,
    this.shortBiasPrice,
  });

  @override
  Widget build(BuildContext context) {
    final actionColor = _signalColor(signal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.terminal_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Strategy Console',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            StatusPill(label: generatedAtLabel, color: AppColors.textMuted),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'AI and ALGO publish the latest side, order type, and risk plan here before execution.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(label: 'Source: $title', color: AppColors.glowCyan),
            StatusPill(label: summary, color: actionColor),
            StatusPill(label: executionLabel, color: executionColor),
            if (confidence != null)
              StatusPill(
                label: 'Confidence ${(confidence! * 100).toStringAsFixed(0)}%',
                color: AppColors.glowAmber,
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 4
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            final spacing = columns == 1 ? 0.0 : 12.0;
            final tileWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            final tiles = [
              _ConsoleMetric(
                label: 'Action',
                value: signal == null ? 'WAIT' : _signalLabel(signal!),
                helper: 'Latest side',
                accent: actionColor,
              ),
              _ConsoleMetric(
                label: 'Order Type',
                value: orderTypeLabel.toUpperCase(),
                helper: 'Execution style',
                accent: AppColors.glowCyan,
              ),
              _ConsoleMetric(
                label: 'Target Entry',
                value: _formatPrice(targetEntryPrice),
                helper: 'Planned price',
                accent: AppColors.glowAmber,
              ),
              _ConsoleMetric(
                label: 'Live Price',
                value: _formatPrice(currentPrice),
                helper: 'Latest candle',
                accent: AppColors.textPrimary,
              ),
              _ConsoleMetric(
                label: 'Leverage',
                value: leverage == null ? '--' : '${leverage}x',
                helper: 'Plan cap',
                accent: AppColors.glowAmber,
              ),
              _ConsoleMetric(
                label: 'Take Profit',
                value: _formatPercent(takeProfitPercent),
                helper: 'Profit target',
                accent: AppColors.positive,
              ),
              _ConsoleMetric(
                label: 'Stop Loss',
                value: _formatPercent(stopLossPercent),
                helper: 'Loss limit',
                accent: AppColors.negative,
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: 12,
              children: [
                for (final tile in tiles)
                  SizedBox(width: tileWidth, child: tile),
              ],
            );
          },
        ),
        if (longBiasPrice != null || shortBiasPrice != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (longBiasPrice != null)
                  _ZoneChip(
                    label:
                        'Long bias at or below ${longBiasPrice!.toStringAsFixed(6)}',
                    color: AppColors.positive,
                  ),
                if (shortBiasPrice != null)
                  _ZoneChip(
                    label:
                        'Short bias at or above ${shortBiasPrice!.toStringAsFixed(6)}',
                    color: AppColors.negative,
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
            border: Border.all(color: actionColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.memory_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Console Output',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                rationale,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _signalColor(TradingSignal? signal) {
    return switch (signal) {
      TradingSignal.buy => AppColors.positive,
      TradingSignal.sell => AppColors.negative,
      TradingSignal.hold => AppColors.glowAmber,
      null => AppColors.textSecondary,
    };
  }

  static String _signalLabel(TradingSignal signal) {
    return switch (signal) {
      TradingSignal.buy => 'LONG',
      TradingSignal.sell => 'SHORT',
      TradingSignal.hold => 'HOLD',
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

class _ZoneChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ZoneChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConsoleError extends StatelessWidget {
  final Object error;

  const _ConsoleError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.terminal_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Strategy Console',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'The strategy plan could not be loaded right now.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          error.toString(),
          style: const TextStyle(color: AppColors.negative, fontSize: 11),
        ),
      ],
    );
  }
}
