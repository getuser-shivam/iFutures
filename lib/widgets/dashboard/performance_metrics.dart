import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/performance_summary.dart';
import '../../providers/trading_provider.dart';
import '../../services/performance_summary_calculator.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';

class PerformanceMetrics extends ConsumerWidget {
  final String symbol;

  const PerformanceMetrics({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradeStreamProvider(symbol));

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Performance Metrics',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              trades.when(
                data: (tradeList) {
                  final summary = PerformanceSummaryCalculator.calculate(tradeList);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getOverallPerformanceColor(summary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getOverallPerformanceText(summary),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          trades.when(
            data: (tradeList) {
              if (tradeList.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No trades yet.\nStart the bot or use Manual mode to generate trades.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final summary = PerformanceSummaryCalculator.calculate(tradeList);
              return _buildMetricsGrid(summary);
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Error loading metrics: $error',
                  style: TextStyle(color: AppColors.negative),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(PerformanceSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricTile(
              title: 'Total Trades',
              value: summary.totalTrades.toString(),
              icon: Icons.swap_horiz,
              color: AppColors.glowCyan,
            ),
            _MetricTile(
              title: 'Win Rate',
              value: '${summary.winRate.toStringAsFixed(0)}%',
              icon: Icons.trending_up,
              color: summary.winRate >= 50 ? AppColors.positive : AppColors.negative,
            ),
            _MetricTile(
              title: 'Total P&L',
              value: '\$${summary.totalPnL.toStringAsFixed(4)}',
              icon: summary.totalPnL >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
              color: summary.totalPnL >= 0 ? AppColors.positive : AppColors.negative,
            ),
            _MetricTile(
              title: 'Best Trade',
              value: '\$${summary.bestTrade.toStringAsFixed(4)}',
              icon: Icons.star,
              color: AppColors.glowAmber,
            ),
            _MetricTile(
              title: 'Worst Trade',
              value: '\$${summary.worstTrade.toStringAsFixed(4)}',
              icon: Icons.warning,
              color: AppColors.warning,
            ),
            _MetricTile(
              title: 'Avg Trade',
              value: '\$${summary.avgTrade.toStringAsFixed(4)}',
              icon: Icons.calculate,
              color: AppColors.textSecondary,
            ),
            _MetricTile(
              title: 'Max Drawdown',
              value: '${summary.maxDrawdown.toStringAsFixed(0)}%',
              icon: Icons.trending_down,
              color: AppColors.negative,
            ),
            _MetricTile(
              title: 'Profit Factor',
              value: _formatProfitFactor(summary.profitFactor),
              icon: Icons.score,
              color: summary.profitFactor >= 1.5 ? AppColors.positive : AppColors.negative,
            ),
          ],
        );
      },
    );
  }

  Color _getOverallPerformanceColor(PerformanceSummary summary) {
    if (summary.totalTrades == 0) return AppColors.textMuted;
    if (summary.winRate >= 60 && summary.totalPnL > 0) return AppColors.positive;
    if (summary.winRate >= 50 && summary.totalPnL > 0) return AppColors.glowCyan;
    if (summary.winRate >= 40) return AppColors.warning;
    return AppColors.negative;
  }

  String _getOverallPerformanceText(PerformanceSummary summary) {
    if (summary.totalTrades == 0) return 'NO DATA';
    if (summary.winRate >= 70) return 'EXCELLENT';
    if (summary.winRate >= 60) return 'GOOD';
    if (summary.winRate >= 50) return 'FAIR';
    if (summary.winRate >= 40) return 'POOR';
    return 'NEEDS WORK';
  }

  String _formatProfitFactor(double value) {
    if (value.isInfinite) return 'INF';
    return value.toStringAsFixed(2);
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.title,
    required this.value,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: tabularFigures(
              const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
