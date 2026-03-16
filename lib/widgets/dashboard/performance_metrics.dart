import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/trade.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import 'app_panel.dart';

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
                data: (tradeList) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getOverallPerformanceColor(tradeList),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getOverallPerformanceText(tradeList),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          trades.when(
            data: (tradeList) => tradeList.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No trades yet\nStart the bot to see performance metrics',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _buildMetricsGrid(tradeList),
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

  Widget _buildMetricsGrid(List<Trade> trades) {
    final metrics = _calculateMetrics(trades);

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
              value: metrics['totalTrades'].toString(),
              icon: Icons.swap_horiz,
              color: AppColors.glowCyan,
            ),
            _MetricTile(
              title: 'Win Rate',
              value: '${metrics['winRate']}%',
              icon: Icons.trending_up,
              color: metrics['winRate'] >= 50 ? AppColors.positive : AppColors.negative,
            ),
            _MetricTile(
              title: 'Total P&L',
              value: '\$${metrics['totalPnL'].toStringAsFixed(4)}',
              icon: metrics['totalPnL'] >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
              color: metrics['totalPnL'] >= 0 ? AppColors.positive : AppColors.negative,
            ),
            _MetricTile(
              title: 'Best Trade',
              value: '\$${metrics['bestTrade'].toStringAsFixed(4)}',
              icon: Icons.star,
              color: AppColors.glowAmber,
            ),
            _MetricTile(
              title: 'Worst Trade',
              value: '\$${metrics['worstTrade'].toStringAsFixed(4)}',
              icon: Icons.warning,
              color: AppColors.warning,
            ),
            _MetricTile(
              title: 'Avg Trade',
              value: '\$${metrics['avgTrade'].toStringAsFixed(4)}',
              icon: Icons.calculate,
              color: AppColors.textSecondary,
            ),
            _MetricTile(
              title: 'Max Drawdown',
              value: '${metrics['maxDrawdown']}%',
              icon: Icons.trending_down,
              color: AppColors.negative,
            ),
            _MetricTile(
              title: 'Profit Factor',
              value: metrics['profitFactor'].toStringAsFixed(2),
              icon: Icons.score,
              color: metrics['profitFactor'] >= 1.5 ? AppColors.positive : AppColors.negative,
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _calculateMetrics(List<Trade> trades) {
    final realizedTrades = trades.where((trade) => trade.kind == 'EXIT' && trade.realizedPnl != null).toList();

    if (realizedTrades.isEmpty) {
      return {
        'totalTrades': 0,
        'winRate': 0.0,
        'totalPnL': 0.0,
        'bestTrade': 0.0,
        'worstTrade': 0.0,
        'avgTrade': 0.0,
        'maxDrawdown': 0.0,
        'profitFactor': 0.0,
      };
    }

    // Calculate basic metrics based on realized PnL
    final winningTrades = realizedTrades.where((trade) => trade.realizedPnl! > 0).toList();
    final losingTrades = realizedTrades.where((trade) => trade.realizedPnl! < 0).toList();

    final totalTrades = realizedTrades.length;
    final winRate = (winningTrades.length / totalTrades) * 100;

    final tradePnLs = realizedTrades.map((trade) => trade.realizedPnl!).toList();
    final totalPnL = tradePnLs.reduce((a, b) => a + b);
    final bestTrade = tradePnLs.isEmpty ? 0.0 : tradePnLs.reduce((a, b) => a > b ? a : b);
    final worstTrade = tradePnLs.isEmpty ? 0.0 : tradePnLs.reduce((a, b) => a < b ? a : b);
    final avgTrade = tradePnLs.isEmpty ? 0.0 : totalPnL / totalTrades;

    // Calculate drawdown (simplified)
    double maxDrawdown = 0.0;
    double peak = 0.0;
    double currentDrawdown = 0.0;

    for (final pnl in tradePnLs) {
      currentDrawdown += pnl;
      if (currentDrawdown > peak) {
        peak = currentDrawdown;
      }
      if (peak > 0) {
        final drawdown = ((peak - currentDrawdown) / peak) * 100;
        if (drawdown > maxDrawdown) {
          maxDrawdown = drawdown;
        }
      }
    }

    // Calculate profit factor
    final grossProfit = winningTrades.fold(0.0, (sum, trade) => sum + trade.realizedPnl!.abs());
    final grossLoss = losingTrades.fold(0.0, (sum, trade) => sum + trade.realizedPnl!.abs());
    final profitFactor = grossLoss == 0 ? double.infinity : grossProfit / grossLoss;

    return {
      'totalTrades': totalTrades,
      'winRate': winRate.round(),
      'totalPnL': totalPnL,
      'bestTrade': bestTrade,
      'worstTrade': worstTrade,
      'avgTrade': avgTrade,
      'maxDrawdown': maxDrawdown.round(),
      'profitFactor': profitFactor.isInfinite ? 999.99 : profitFactor,
    };
  }

  Color _getOverallPerformanceColor(List<Trade> trades) {
    final metrics = _calculateMetrics(trades);
    final winRate = metrics['winRate'];
    final totalPnL = metrics['totalPnL'];

    if (winRate >= 60 && totalPnL > 0) return AppColors.positive;
    if (winRate >= 50 && totalPnL > 0) return AppColors.glowCyan;
    if (winRate >= 40) return AppColors.warning;
    return AppColors.negative;
  }

  String _getOverallPerformanceText(List<Trade> trades) {
    final metrics = _calculateMetrics(trades);
    final winRate = metrics['winRate'];

    if (winRate >= 70) return 'EXCELLENT';
    if (winRate >= 60) return 'GOOD';
    if (winRate >= 50) return 'FAIR';
    if (winRate >= 40) return 'POOR';
    return 'NEEDS WORK';
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
