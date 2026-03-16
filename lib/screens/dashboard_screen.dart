import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../widgets/mode_selector.dart';
import '../widgets/price_chart.dart';
import '../widgets/trade_history.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const symbol = 'GALAUSDT';
    final ticker = ref.watch(tickerStreamProvider(symbol));
    final isRunning = ref.watch(isBotRunningProvider);
    final engineAsync = ref.watch(tradingEngineProvider(symbol));
    final settingsInit = ref.watch(settingsInitProvider);

    if (settingsInit.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (settingsInit.hasError) {
      return Scaffold(
        body: Center(child: Text('Settings Error: ${settingsInit.error}')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('iFutures - GALAUSDT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade900, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
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
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      loading: () => const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
                const ModeSelector(),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: PriceChart(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const TradeHistory(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(isRunning ? 'Bot: Running' : 'Bot: Stopped'),
                  backgroundColor: isRunning ? Colors.green.shade600 : Colors.red.shade600,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                engineAsync.when(
                  data: (_) => Chip(
                    label: const Text('Engine: Ready'),
                    backgroundColor: Colors.green.shade700,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  loading: () => Chip(
                    label: const Text('Engine: Loading...'),
                    backgroundColor: Colors.orange.shade700,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                  error: (e, _) => Chip(
                    label: const Text('Engine: Error'),
                    backgroundColor: Colors.red.shade700,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'GALAUSDT Market Insights - Live Monitoring',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isRunning || engineAsync.isLoading
                      ? null 
                      : () {
                          engineAsync.whenData((engine) {
                            ref.read(isBotRunningProvider.notifier).state = true;
                            engine.start();
                          });
                        },
                    child: const Text('START BOT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: !isRunning || engineAsync.isLoading
                      ? null 
                      : () {
                          engineAsync.whenData((engine) {
                            ref.read(isBotRunningProvider.notifier).state = false;
                            engine.stop();
                          });
                        },
                    child: const Text('STOP BOT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
