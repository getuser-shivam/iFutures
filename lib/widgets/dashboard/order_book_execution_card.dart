import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/strategy_mode.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../../trading/strategy.dart';
import '../common/app_panel.dart';
import '../common/status_pill.dart';

class OrderBookExecutionCard extends ConsumerWidget {
  final String symbol;

  const OrderBookExecutionCard({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(orderBookSnapshotProvider(symbol));
    final planAsync = ref.watch(decisionPlanStreamProvider(symbol));
    final openOrdersAsync = ref.watch(openOrderStreamProvider(symbol));
    final currentMode = ref.watch(currentStrategyModeProvider);
    final isRunning = ref.watch(isBotRunningProvider(symbol));
    final snapshot = snapshotAsync.valueOrNull;
    final plan = planAsync.valueOrNull;
    final openOrders = openOrdersAsync.valueOrNull ?? const [];
    final title = switch (currentMode) {
      StrategyMode.manual => 'Order Book Analysis',
      _ => 'Order Book & Execution',
    };
    final summary = _statusSummary(
      currentMode: currentMode,
      isRunning: isRunning,
      plan: plan,
      openOrderCount: openOrders.length,
    );

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.query_stats,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (plan?.executionHint?.trim().isNotEmpty == true)
                StatusPill(
                  label: plan!.executionHint!,
                  color: AppColors.glowAmber,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snapshot == null
                ? 'Waiting for a live Binance depth snapshot. Once the book syncs, the app can compare spread, imbalance, and slippage before choosing execution.'
                : 'Live Binance depth for $symbol. This card helps explain whether the bot is only analyzing, waiting on a HOLD plan, or actually working a Binance order.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: summary.color.withValues(alpha: 0.28)),
            ),
            child: Text(
              summary.message,
              style: TextStyle(
                color: summary.color,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1180
                  ? 4
                  : constraints.maxWidth > 760
                  ? 3
                  : 2;
              final spacing = 12.0;
              final tileWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              final metrics = [
                _OrderBookMetric(
                  label: 'Best Bid',
                  value: _formatPrice(snapshot?.bestBid),
                  helper: 'Top buyer',
                  accent: AppColors.positive,
                ),
                _OrderBookMetric(
                  label: 'Best Ask',
                  value: _formatPrice(snapshot?.bestAsk),
                  helper: 'Top seller',
                  accent: AppColors.negative,
                ),
                _OrderBookMetric(
                  label: 'Spread',
                  value: snapshot?.spreadPercent == null
                      ? '--'
                      : '${snapshot!.spreadPercent!.toStringAsFixed(4)}%',
                  helper: snapshot?.spread == null
                      ? 'Bid / ask gap'
                      : 'Abs ${_formatPrice(snapshot!.spread)}',
                  accent: AppColors.glowAmber,
                ),
                _OrderBookMetric(
                  label: 'Mid Price',
                  value: _formatPrice(snapshot?.midPrice),
                  helper: 'Book midpoint',
                  accent: AppColors.textPrimary,
                ),
                _OrderBookMetric(
                  label: 'Bid Depth',
                  value: _formatUsdt(snapshot?.bidDepthNotional),
                  helper: '${snapshot?.levelsAnalyzed ?? 0} levels analyzed',
                  accent: AppColors.positive,
                ),
                _OrderBookMetric(
                  label: 'Ask Depth',
                  value: _formatUsdt(snapshot?.askDepthNotional),
                  helper: '${snapshot?.levelsAnalyzed ?? 0} levels analyzed',
                  accent: AppColors.negative,
                ),
                _OrderBookMetric(
                  label: 'Imbalance',
                  value: snapshot == null
                      ? '--'
                      : '${snapshot.imbalancePercent.toStringAsFixed(1)}%',
                  helper: 'Bid vs ask pressure',
                  accent: snapshot == null
                      ? AppColors.textSecondary
                      : (snapshot.imbalancePercent >= 0
                            ? AppColors.positive
                            : AppColors.negative),
                ),
                _OrderBookMetric(
                  label: 'Plan Qty',
                  value: snapshot == null
                      ? '--'
                      : _formatQuantity(snapshot.plannedQuantity),
                  helper: 'Sized for AI/manual plan',
                  accent: AppColors.glowAmber,
                ),
                _OrderBookMetric(
                  label: 'Buy Slip',
                  value: snapshot?.estimatedBuySlippagePercent == null
                      ? '--'
                      : '${snapshot!.estimatedBuySlippagePercent!.toStringAsFixed(4)}%',
                  helper: 'Est. market buy impact',
                  accent: AppColors.glowCyan,
                ),
                _OrderBookMetric(
                  label: 'Sell Slip',
                  value: snapshot?.estimatedSellSlippagePercent == null
                      ? '--'
                      : '${snapshot!.estimatedSellSlippagePercent!.toStringAsFixed(4)}%',
                  helper: 'Est. market sell impact',
                  accent: AppColors.glowCyan,
                ),
                _OrderBookMetric(
                  label: 'Est. Buy Fill',
                  value: _formatPrice(snapshot?.estimatedBuyFillPrice),
                  helper: 'Sweep average',
                  accent: AppColors.positive,
                ),
                _OrderBookMetric(
                  label: 'Est. Sell Fill',
                  value: _formatPrice(snapshot?.estimatedSellFillPrice),
                  helper: 'Sweep average',
                  accent: AppColors.negative,
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: plan?.orderTypeLabel ?? 'Waiting',
                color: _executionColor(plan?.orderTypeLabel),
              ),
              StatusPill(
                label: plan?.orderBookTrendLabel ?? 'Book trend pending',
                color: AppColors.textPrimary,
              ),
              if (openOrders.isNotEmpty)
                StatusPill(
                  label:
                      '${openOrders.length} working Binance order${openOrders.length == 1 ? '' : 's'}',
                  color: AppColors.glowCyan,
                ),
              StatusPill(
                label: snapshot == null
                    ? 'Book update pending'
                    : 'Updated ${DateFormat('HH:mm:ss').format(snapshot.capturedAt.toLocal())}',
                color: AppColors.glowAmber,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Visible depth and imbalance show quoted liquidity, not verified “whale” intent. Orders can be cancelled or spoofed, so the AI treats book pressure as context rather than proof of a future move.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPrice(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    final digits = value >= 100
        ? 2
        : value >= 1
        ? 4
        : 6;
    return value.toStringAsFixed(digits);
  }

  static String _formatQuantity(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    if (value >= 1000) {
      return value.toStringAsFixed(2);
    }
    if (value >= 1) {
      return value.toStringAsFixed(4);
    }
    return value.toStringAsFixed(6);
  }

  static String _formatUsdt(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    final digits = value >= 1000
        ? 2
        : value >= 1
        ? 3
        : 6;
    return '${value.toStringAsFixed(digits)} USDT';
  }

  static Color _executionColor(String? label) {
    switch ((label ?? '').toLowerCase()) {
      case 'market':
        return AppColors.negative;
      case 'limit':
        return AppColors.glowCyan;
      case 'post only':
        return AppColors.positive;
      case 'scaled':
        return AppColors.glowAmber;
      default:
        return AppColors.textSecondary;
    }
  }

  static _OrderBookStatusSummary _statusSummary({
    required StrategyMode currentMode,
    required bool isRunning,
    required StrategyTradePlan? plan,
    required int openOrderCount,
  }) {
    if (currentMode == StrategyMode.manual) {
      return const _OrderBookStatusSummary(
        message:
            'Manual mode is active. This card is analysis only until you send a manual order from the ticket.',
        color: AppColors.glowAmber,
      );
    }
    if (!isRunning) {
      return const _OrderBookStatusSummary(
        message:
            'Auto execution is OFF. No buy or sell will be sent until you press START AUTO in the Trading Desk.',
        color: AppColors.warning,
      );
    }
    if (openOrderCount > 0) {
      return _OrderBookStatusSummary(
        message:
            'Auto execution is ON and Binance currently has $openOrderCount working order${openOrderCount == 1 ? '' : 's'}. If nothing filled yet, the plan is likely using a passive entry such as Limit, Post Only, or Scaled.',
        color: AppColors.glowCyan,
      );
    }
    if (plan == null || plan.signal == TradingSignal.hold) {
      return const _OrderBookStatusSummary(
        message:
            'Auto execution is ON, but the current strategy plan is HOLD/WAITING. In this state the bot is not supposed to send a buy or sell yet.',
        color: AppColors.textSecondary,
      );
    }
    return _OrderBookStatusSummary(
      message:
          'Auto execution is ON and the current plan is ${plan.actionLabel} using ${plan.orderTypeLabel}. If a Binance order still does not appear, the next step is to inspect the terminal log for the exact rejection message.',
      color: _executionColor(plan.orderTypeLabel),
    );
  }
}

class _OrderBookStatusSummary {
  final String message;
  final Color color;

  const _OrderBookStatusSummary({required this.message, required this.color});
}

class _OrderBookMetric extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color accent;

  const _OrderBookMetric({
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
