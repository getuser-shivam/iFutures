import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';

class OpenPositionCard extends ConsumerWidget {
  final String symbol;
  final double? latestPrice;

  const OpenPositionCard({super.key, required this.symbol, this.latestPrice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(positionStreamProvider(symbol));
    final riskAsync = ref.watch(riskSettingsProvider);

    return positionAsync.when(
      data: (position) {
        final risk = riskAsync.valueOrNull;
        final isOpen = position != null;
        final sideLabel = isOpen
            ? (position!.isLong ? 'LONG' : 'SHORT')
            : 'NONE';
        final sideColor = position == null
            ? Colors.blueGrey
            : (position.isLong ? Colors.green : Colors.red);

        final currentPrice = latestPrice;
        final entryPrice = position?.entryPrice;
        final quantity = position?.quantity;
        final leverage = (risk?.leverage ?? 1).clamp(1, 125);
        final exposure =
            position == null || entryPrice == null || quantity == null
            ? null
            : entryPrice * quantity;
        final marginUsed = exposure == null ? null : exposure / leverage;

        double? pnl;
        double? pnlPct;
        if (position != null && currentPrice != null && entryPrice != null) {
          pnl = position.isLong
              ? (currentPrice - entryPrice) * position.quantity
              : (entryPrice - currentPrice) * position.quantity;
          pnlPct = position.isLong
              ? ((currentPrice - entryPrice) / entryPrice) * 100
              : ((entryPrice - currentPrice) / entryPrice) * 100;
        }
        final roePercent = pnl == null || marginUsed == null || marginUsed == 0
            ? null
            : (pnl / marginUsed) * 100;

        final stopLossPercent = risk?.stopLossPercent ?? 0.0;
        final takeProfitPercent = risk?.takeProfitPercent ?? 0.0;
        final stopLossPrice = position != null && stopLossPercent > 0
            ? position.stopLossPrice(stopLossPercent)
            : null;
        final takeProfitPrice = position != null && takeProfitPercent > 0
            ? position.takeProfitPrice(takeProfitPercent)
            : null;

        return AppPanel(
          accent: isOpen ? sideColor : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.stacked_line_chart,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Open Position',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sideColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      sideLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!isOpen)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No open position for $symbol.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Next ticket starts from ${_formatQuantity(risk?.tradeQuantity)} units at ${leverage}x leverage.',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                    final spacing = columns == 1 ? 0.0 : 12.0;
                    final tileWidth =
                        (constraints.maxWidth - (spacing * (columns - 1))) /
                        columns;
                    final metrics = [
                      _InfoBlock(
                        label: 'Entry',
                        value: _formatPrice(entryPrice),
                      ),
                      _InfoBlock(
                        label: 'Qty',
                        value: _formatQuantity(quantity),
                      ),
                      _InfoBlock(
                        label: 'Last',
                        value: _formatPrice(currentPrice),
                      ),
                      _InfoBlock(
                        label: 'Exposure',
                        value: _formatUsdt(exposure),
                        helper: 'Entry x qty',
                      ),
                      _InfoBlock(
                        label: 'Est. Margin',
                        value: _formatUsdt(marginUsed),
                        helper: '${leverage}x leverage',
                      ),
                      _InfoBlock(
                        label: 'Unrealized',
                        value: _formatSignedUsdt(pnl),
                        valueColor: pnl == null
                            ? AppColors.textSecondary
                            : (pnl >= 0
                                  ? AppColors.positive
                                  : AppColors.negative),
                        helper: pnlPct == null
                            ? null
                            : 'Price ${pnlPct.toStringAsFixed(2)}%',
                      ),
                      _InfoBlock(
                        label: 'Stop Loss',
                        value: _formatPrice(stopLossPrice),
                        helper: stopLossPercent > 0
                            ? '${stopLossPercent.toStringAsFixed(2)}%'
                            : 'OFF',
                      ),
                      _InfoBlock(
                        label: 'Take Profit',
                        value: _formatPrice(takeProfitPrice),
                        helper: takeProfitPercent > 0
                            ? '${takeProfitPercent.toStringAsFixed(2)}%'
                            : 'OFF',
                      ),
                      _InfoBlock(
                        label: 'ROE',
                        value: roePercent == null
                            ? '--'
                            : '${roePercent.toStringAsFixed(2)}%',
                        valueColor: roePercent == null
                            ? AppColors.textSecondary
                            : (roePercent >= 0
                                  ? AppColors.positive
                                  : AppColors.negative),
                        helper: 'PnL vs est. margin',
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
            ],
          ),
        );
      },
      loading: () => _loadingCard(),
      error: (error, stack) => _errorCard(error.toString()),
    );
  }

  String _formatPrice(double? value) {
    if (value == null || value <= 0) return '--';
    return value.toStringAsFixed(value >= 100 ? 2 : 6);
  }

  String _formatQuantity(double? value) {
    if (value == null || value <= 0) return '--';
    if (value >= 1000) return value.toStringAsFixed(2);
    if (value >= 1) return value.toStringAsFixed(4);
    return value.toStringAsFixed(6);
  }

  String _formatUsdt(double? value) {
    if (value == null || value <= 0) return '--';
    final digits = value >= 100
        ? 2
        : value >= 1
        ? 3
        : 6;
    return '${value.toStringAsFixed(digits)} USDT';
  }

  String _formatSignedUsdt(double? value) {
    if (value == null) return '--';
    if (value == 0) return '0.00 USDT';
    final prefix = value > 0 ? '+' : '-';
    return '$prefix${_formatUsdt(value.abs())}';
  }

  Widget _loadingCard() {
    return const AppPanel(child: Center(child: CircularProgressIndicator()));
  }

  Widget _errorCard(String message) {
    return AppPanel(
      accent: AppColors.negative,
      child: Text(
        'Position error: $message',
        style: const TextStyle(color: AppColors.negative),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;
  final Color? valueColor;

  const _InfoBlock({
    required this.label,
    required this.value,
    this.helper,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (helper != null)
            Text(
              helper!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
