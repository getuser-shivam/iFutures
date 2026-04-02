import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/performance_summary.dart';
import '../../providers/trading_provider.dart';
import '../../services/performance_summary_calculator.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';
import '../common/status_pill.dart';

class DailyPerformanceCard extends ConsumerWidget {
  final String symbol;

  const DailyPerformanceCard({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradeStreamProvider(symbol));

    return trades.when(
      data: (tradeList) {
        final now = DateTime.now();
        final PerformanceSummary summary =
            PerformanceSummaryCalculator.calculateForDay(tradeList, now);
        final dayLabel = DateFormat('MMM d').format(now);

        return AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.today_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Daily Performance',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  StatusPill(
                    label: '${summary.totalTrades} trades',
                    color: summary.hasData
                        ? AppColors.glowCyan
                        : AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Closed trades since local midnight - $dayLabel',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              if (!summary.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No closed trades yet today.\nThe summary updates after the next exit.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 3
                        : constraints.maxWidth > 600
                        ? 2
                        : 1;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _SummaryTile(
                          title: 'Daily P&L',
                          value: _formatPnl(summary.totalPnL),
                          icon: summary.totalPnL >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: summary.totalPnL >= 0
                              ? AppColors.positive
                              : AppColors.negative,
                          helper: 'Realized today',
                        ),
                        _SummaryTile(
                          title: 'Win Rate',
                          value: '${summary.winRate.toStringAsFixed(0)}%',
                          icon: Icons.emoji_events_outlined,
                          color: summary.winRate >= 50
                              ? AppColors.positive
                              : AppColors.warning,
                          helper:
                              '${summary.winningTrades}/${summary.totalTrades} wins',
                        ),
                        _SummaryTile(
                          title: 'Drawdown',
                          value: '${summary.maxDrawdown.toStringAsFixed(0)}%',
                          icon: Icons.waterfall_chart,
                          color: AppColors.warning,
                          helper: 'Peak to trough',
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
      loading: () =>
          const AppPanel(child: Center(child: CircularProgressIndicator())),
      error: (error, stack) => AppPanel(
        accent: AppColors.negative,
        child: Text(
          'Daily performance error: $error',
          style: const TextStyle(color: AppColors.negative),
        ),
      ),
    );
  }

  String _formatPnl(double value) {
    final formatted = value.abs().toStringAsFixed(4);
    return value >= 0 ? '\$$formatted' : '-\$$formatted';
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: tabularFigures(
              TextStyle(
                color: color,
                fontSize: 17,
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
