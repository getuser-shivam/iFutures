import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/trading_provider.dart';
import '../../models/trade.dart';
import '../../trading/trading_engine.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';
import '../common/app_toast.dart';

class TradeHistory extends ConsumerWidget {
  final String symbol;

  const TradeHistory({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradeStreamProvider(symbol));
    final engineAsync = ref.watch(tradingEngineProvider(symbol));
    final tradeList = trades.maybeWhen(
      data: (list) => list,
      orElse: () => const <Trade>[],
    );

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Trade History',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${tradeList.length} trades',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: tradeList.isEmpty
                        ? null
                        : () async {
                            try {
                              final exportService = ref.read(tradeCsvExportServiceProvider);
                              await exportService.exportTrades(
                                symbol: symbol,
                                trades: tradeList,
                              );
                              if (!context.mounted) return;
                              showAppToast(
                                context,
                                'CSV exported',
                                backgroundColor: AppColors.glowCyan.withOpacity(0.95),
                                foregroundColor: Colors.white,
                                icon: Icons.download_outlined,
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              showAppToast(
                                context,
                                'CSV export failed: $error',
                                backgroundColor: AppColors.negative.withOpacity(0.95),
                                foregroundColor: Colors.white,
                                icon: Icons.error_outline,
                              );
                            }
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.glowCyan,
                    ),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('EXPORT'),
                  ),
                  TextButton.icon(
                    onPressed: tradeList.isEmpty || engineAsync.isLoading
                        ? null
                        : () async {
                            if (engineAsync is AsyncData<TradingEngine>) {
                              await engineAsync.value.clearTrades();
                              if (!context.mounted) return;
                              showAppToast(
                                context,
                                'Trade history cleared',
                                backgroundColor: AppColors.warning.withOpacity(0.95),
                                foregroundColor: Colors.white,
                                icon: Icons.delete_outline,
                              );
                            }
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.warning,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('CLEAR'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'CSV exports save to your Documents/iFutures/exports folder.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          trades.when(
            data: (tradeList) {
              if (tradeList.isEmpty) {
                return const Center(
                  child: Text(
                    'No trades yet. Start the bot or use Manual mode.',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                itemCount: tradeList.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final trade = tradeList[tradeList.length - 1 - index]; // Show newest first
                  return _buildTradeItem(trade);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => Center(
              child: Text(
                'Error loading trades: $error',
                style: const TextStyle(color: AppColors.negative),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeItem(Trade trade) {
    final isBuy = trade.side == 'BUY';
    final color = isBuy ? AppColors.positive : AppColors.negative;
    final isExit = trade.kind == 'EXIT';
    final badgeText = isExit && trade.reason != null && trade.reason!.isNotEmpty
        ? trade.reason!.replaceAll('_', ' ').toUpperCase()
        : trade.kind;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trade.side} ${trade.symbol} (${trade.kind})',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('HH:mm:ss').format(trade.timestamp),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price: \$${trade.price.toStringAsFixed(6)}',
                style: tabularFigures(const TextStyle(color: AppColors.textPrimary)),
              ),
              Text(
                'Qty: ${trade.quantity}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Strategy: ${trade.strategy}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trade.status == 'simulated' ? AppColors.warning : AppColors.glowCyan,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (isExit && trade.realizedPnl != null) ...[
            const SizedBox(height: 4),
            Text(
              'PnL: ${trade.realizedPnl!.toStringAsFixed(4)}',
              style: TextStyle(
                color: trade.realizedPnl! >= 0 ? AppColors.positive : AppColors.negative,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
