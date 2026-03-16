import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/trading_provider.dart';
import '../models/trade.dart';

class TradeHistory extends ConsumerWidget {
  const TradeHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradeStreamProvider('GALAUSDT'));

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
              const Icon(Icons.history, color: Colors.white70),
              const SizedBox(width: 8),
              const Text(
                'Trade History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              trades.when(
                data: (tradeList) => Text(
                  '${tradeList.length} trades',
                  style: const TextStyle(color: Colors.white70),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: trades.when(
              data: (tradeList) {
                if (tradeList.isEmpty) {
                  return const Center(
                    child: Text(
                      'No trades yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: tradeList.length,
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
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeItem(Trade trade) {
    final isBuy = trade.side == 'BUY';
    final color = isBuy ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade700,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
                    '${trade.side} ${trade.symbol}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                DateFormat('HH:mm:ss').format(trade.timestamp),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price: \$${trade.price.toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Qty: ${trade.quantity}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Strategy: ${trade.strategy}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trade.status == 'simulated' ? Colors.orange.shade800 : Colors.green.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trade.status.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}