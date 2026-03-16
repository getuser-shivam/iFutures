import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/trade.dart';
import '../../providers/trading_provider.dart';

class PerformanceMetrics extends ConsumerWidget {
  final String symbol;

  const PerformanceMetrics({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradeStreamProvider(symbol));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white70),
              const SizedBox(width: 8),
              const Text(
                'Performance Metrics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              trades.when(
                data: (tradeList) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getOverallPerformanceColor(tradeList),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getOverallPerformanceText(tradeList),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
                        style: TextStyle(color: Colors.white54),
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
                  style: const TextStyle(color: Colors.red),
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

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard(
          'Total Trades',
          metrics['totalTrades'].toString(),
          Icons.swap_horiz,
          Colors.blue,
        ),
        _buildMetricCard(
          'Win Rate',
          '${metrics['winRate']}%',
          Icons.trending_up,
          metrics['winRate'] >= 50 ? Colors.green : Colors.red,
        ),
        _buildMetricCard(
          'Total P&L',
          '\$${metrics['totalPnL'].toStringAsFixed(4)}',
          metrics['totalPnL'] >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
          metrics['totalPnL'] >= 0 ? Colors.green : Colors.red,
        ),
        _buildMetricCard(
          'Best Trade',
          '\$${metrics['bestTrade'].toStringAsFixed(4)}',
          Icons.star,
          Colors.amber,
        ),
        _buildMetricCard(
          'Worst Trade',
          '\$${metrics['worstTrade'].toStringAsFixed(4)}',
          Icons.warning,
          Colors.orange,
        ),
        _buildMetricCard(
          'Avg Trade',
          '\$${metrics['avgTrade'].toStringAsFixed(4)}',
          Icons.calculate,
          Colors.purple,
        ),
        _buildMetricCard(
          'Max Drawdown',
          '${metrics['maxDrawdown']}%',
          Icons.trending_down,
          Colors.red.shade700,
        ),
        _buildMetricCard(
          'Profit Factor',
          metrics['profitFactor'].toStringAsFixed(2),
          Icons.score,
          metrics['profitFactor'] >= 1.5 ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade700,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

    if (winRate >= 60 && totalPnL > 0) return Colors.green.shade600;
    if (winRate >= 50 && totalPnL > 0) return Colors.blue.shade600;
    if (winRate >= 40) return Colors.orange.shade600;
    return Colors.red.shade600;
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
