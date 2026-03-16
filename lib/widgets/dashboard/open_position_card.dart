import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';

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

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stacked_line_chart, color: Colors.white70),
                  const SizedBox(width: 8),
                  const Text(
                    'Open Position',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sideColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      sideLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isOpen)
                Text(
                  'No open position for $symbol.',
                  style: const TextStyle(color: Colors.white70),
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
              const SizedBox(height: 8),
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
                          ? Colors.white70
                          : (pnl >= 0 ? Colors.greenAccent : Colors.redAccent),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Text(
        'Position error: $message',
        style: const TextStyle(color: Colors.redAccent),
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
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (helper != null)
            Text(
              helper!,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
