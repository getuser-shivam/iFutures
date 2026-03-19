import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/backtest_result.dart';
import '../../models/kline.dart';
import '../../models/trade.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../common/action_button.dart';
import '../common/app_panel.dart';
import '../common/app_toast.dart';
import '../common/status_pill.dart';

class BacktestCard extends ConsumerStatefulWidget {
  final String symbol;

  const BacktestCard({super.key, required this.symbol});

  @override
  ConsumerState<BacktestCard> createState() => _BacktestCardState();
}

class _BacktestCardState extends ConsumerState<BacktestCard> {
  BacktestResult? _result;
  String? _errorMessage;
  bool _isRunning = false;
  DateTime? _lastRunAt;

  @override
  Widget build(BuildContext context) {
    final strategy = ref.watch(currentStrategyProvider);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.query_stats_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Backtest Lab',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_result != null)
                StatusPill(
                  label: '${_result!.summary.totalTrades} exits',
                  color: _result!.summary.hasData
                      ? AppColors.glowCyan
                      : AppColors.textMuted,
                ),
              if (_result == null)
                const StatusPill(label: 'READY', color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Runs the selected strategy over the latest 500 candles and reuses the same risk rules as live trading.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: 'Symbol: ${widget.symbol}',
                color: AppColors.glowAmber,
              ),
              StatusPill(
                label: strategy == null
                    ? 'Strategy: --'
                    : 'Strategy: ${strategy.name}',
                color: strategy == null
                    ? AppColors.textMuted
                    : AppColors.glowCyan,
              ),
              if (_lastRunAt != null)
                StatusPill(
                  label: 'Last run: ${DateFormat('HH:mm').format(_lastRunAt!)}',
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: _isRunning ? 'RUNNING...' : 'RUN BACKTEST',
                  icon: Icons.play_arrow,
                  color: AppColors.glowCyan,
                  onPressed: _isRunning ? null : _runBacktest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActionButton(
                  label: 'CLEAR',
                  icon: Icons.clear,
                  color: AppColors.textSecondary,
                  onPressed: _result == null && _errorMessage == null
                      ? null
                      : _clearResult,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.negative, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ],
          if (_result == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Run a backtest to compare the strategy against historical candles.\nManual mode will stay flat by design.',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900
                        ? 4
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
                        _MetricTile(
                          title: 'Net P&L',
                          value: _formatMoney(_result!.netPnL),
                          icon: _result!.netPnL >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: _result!.netPnL >= 0
                              ? AppColors.positive
                              : AppColors.negative,
                          helper:
                              'Balance: ${_formatMoney(_result!.endingBalance)}',
                        ),
                        _MetricTile(
                          title: 'Win Rate',
                          value:
                              '${_result!.summary.winRate.toStringAsFixed(0)}%',
                          icon: Icons.emoji_events_outlined,
                          color: _result!.summary.winRate >= 50
                              ? AppColors.positive
                              : AppColors.warning,
                          helper:
                              '${_result!.summary.winningTrades}/${_result!.summary.totalTrades} exits',
                        ),
                        _MetricTile(
                          title: 'Profit Factor',
                          value: _formatProfitFactor(
                            _result!.summary.profitFactor,
                          ),
                          icon: Icons.score,
                          color: _result!.summary.profitFactor >= 1.5
                              ? AppColors.positive
                              : AppColors.warning,
                          helper: 'Gross profit / loss',
                        ),
                        _MetricTile(
                          title: 'Max Drawdown',
                          value:
                              '${_result!.summary.maxDrawdown.toStringAsFixed(0)}%',
                          icon: Icons.waterfall_chart,
                          color: AppColors.warning,
                          helper: '${_result!.candlesProcessed} candles',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryLine(
                        label: 'Period',
                        value:
                            '${DateFormat('MMM d HH:mm').format(_result!.periodStart)} - ${DateFormat('MMM d HH:mm').format(_result!.periodEnd)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryLine(
                        label: 'Candles processed',
                        value: _result!.candlesProcessed.toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Recent exits',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (_recentExitTrades.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No exit trades were generated for this sample.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  Column(
                    children: _recentExitTrades
                        .map(
                          (trade) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ExitRow(trade: trade),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<Trade> get _recentExitTrades {
    if (_result == null) return const [];
    final exitTrades = _result!.trades
        .where((trade) => trade.kind == 'EXIT')
        .toList();
    if (exitTrades.length <= 3) return exitTrades.reversed.toList();
    return exitTrades.sublist(exitTrades.length - 3).reversed.toList();
  }

  Future<void> _runBacktest() async {
    setState(() {
      _isRunning = true;
      _errorMessage = null;
    });

    try {
      final strategy = ref.read(currentStrategyProvider);
      if (strategy == null) {
        throw StateError('Strategy not initialized');
      }

      final riskSettings = await ref.read(riskSettingsProvider.future);
      final api = await ref.read(binanceApiProvider.future);
      final rawKlines = await api.getKlines(symbol: widget.symbol, limit: 500);
      final klines = rawKlines
          .map((entry) => Kline.fromJson(entry as List<dynamic>))
          .toList();

      final service = ref.read(backtestServiceProvider);
      final result = await service.run(
        symbol: widget.symbol,
        strategy: strategy,
        riskSettings: riskSettings,
        klines: klines,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _lastRunAt = DateTime.now();
      });

      showAppToast(
        context,
        'Backtest complete',
        backgroundColor: AppColors.glowCyan.withOpacity(0.95),
        foregroundColor: Colors.white,
        icon: Icons.query_stats_outlined,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Backtest failed: $error';
      });
      showAppToast(
        context,
        'Backtest failed',
        backgroundColor: AppColors.negative.withOpacity(0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _clearResult() {
    setState(() {
      _result = null;
      _errorMessage = null;
      _lastRunAt = null;
    });
  }

  String _formatMoney(double value) {
    final formatted = value.abs().toStringAsFixed(4);
    return value >= 0 ? '\$$formatted' : '-\$$formatted';
  }

  String _formatProfitFactor(double value) {
    if (value.isInfinite) return 'INF';
    return value.toStringAsFixed(2);
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;

  const _MetricTile({
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

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitRow extends StatelessWidget {
  final Trade trade;

  const _ExitRow({required this.trade});

  @override
  Widget build(BuildContext context) {
    final pnl = trade.realizedPnl ?? 0;
    final color = pnl >= 0 ? AppColors.positive : AppColors.negative;
    final label =
        trade.reason?.replaceAll('_', ' ').toUpperCase() ?? trade.kind;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            trade.side == 'BUY' ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trade.side} ${trade.symbol}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('HH:mm:ss').format(trade.timestamp)} - $label',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(4)}',
            style: tabularFigures(
              TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
