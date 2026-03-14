import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticker = ref.watch(tickerStreamProvider('GALAUSDT'));
    final strategy = ref.watch(currentStrategyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('iFutures - GALAUSDT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueGrey.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Price', style: TextStyle(color: Colors.white70)),
                    ticker.when(
                      data: (data) => Text(
                        '${data['c']} USDT',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Mode', style: TextStyle(color: Colors.white70)),
                    Text(
                      strategy.name,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('Chart & Order History Placeholder'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () {
                      ref.read(tradingEngineProvider).start();
                    },
                    child: const Text('START BOT'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    onPressed: () {
                      ref.read(tradingEngineProvider).stop();
                    },
                    child: const Text('STOP BOT'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
