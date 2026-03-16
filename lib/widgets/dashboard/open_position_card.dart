import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import 'app_panel.dart';

class OpenPositionCard extends ConsumerWidget {
  final String symbol;
  final double? latestPrice;

  const OpenPositionCard({
    super.key,
    required this.symbol,
    this.latestPrice,
  });

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
                  const Icon(Icons.stacked_line_chart, color: AppColors.textSecondary, size: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                Text(
                  'No open position for $symbol.',
                  style: const TextStyle(color: AppColors.textSecondary),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _InfoBlock(
                        label: 'Entry',
                        value: _formatPrice(entryPrice),
                      ),
                    ),
                    Expanded(
                      child: _InfoBlock(
                        label: 'Qty',
                        value: quantity?.toStringAsFixed(4) ?? '--',
                      ),
                    ),
                    Expanded(
                      child: _InfoBlock(
                        label: 'Last',
                        value: currentPrice != null ? _formatPrice(currentPrice) : '--',
                      ),
                    ),
                  ],
                ),
              const Divider(height: 20, color: AppColors.border),
              Row(
                children: [
                  Expanded(
                    child: _InfoBlock(
                      label: 'Stop Loss',
                      value: stopLossPrice != null ? _formatPrice(stopLossPrice) : '--',
                      helper: stopLossPercent > 0 ? '${stopLossPercent.toStringAsFixed(2)}%' : null,
                    ),
                  ),
                  Expanded(
                    child: _InfoBlock(
                      label: 'Take Profit',
                      value: takeProfitPrice != null ? _formatPrice(takeProfitPrice) : '--',
                      helper: takeProfitPercent > 0 ? '${takeProfitPercent.toStringAsFixed(2)}%' : null,
                    ),
                  ),
                  Expanded(
                    child: _InfoBlock(
                      label: 'Unrealized',
                      value: pnl != null ? pnl.toStringAsFixed(4) : '--',
                      valueColor: pnl == null
                          ? AppColors.textSecondary
                          : (pnl >= 0 ? AppColors.positive : AppColors.negative),
                      helper: pnlPct != null ? '${pnlPct.toStringAsFixed(2)}%' : null,
                    ),
                  ),
                ],
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
    if (value == null) return '--';
    return value.toStringAsFixed(6);
  }

  Widget _loadingCard() {
    return const AppPanel(
      child: Center(child: CircularProgressIndicator()),
    );
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
