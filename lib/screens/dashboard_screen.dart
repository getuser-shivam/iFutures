import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../trading/trading_engine.dart';
import '../trading/manual_strategy.dart';
import '../widgets/dashboard/mode_selector.dart';
import '../widgets/dashboard/open_position_card.dart';
import '../widgets/dashboard/price_chart.dart';
import '../widgets/dashboard/trade_history.dart';
import '../widgets/dashboard/performance_metrics.dart';
import 'settings_screen.dart';
import 'gallery_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(selectedSymbolProvider);
    final ticker = ref.watch(tickerStreamProvider(symbol));
    final isRunning = ref.watch(isBotRunningProvider(symbol));
    final engineAsync = ref.watch(tradingEngineProvider(symbol));
    final currentStrategy = ref.watch(currentStrategyProvider);
    final isManual = currentStrategy is ManualStrategy;
    final settingsInit = ref.watch(settingsInitProvider);
    const symbols = ['GALAUSDT', 'BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT'];
    final latestPrice = ticker.maybeWhen(
      data: (data) => double.tryParse(data['c']?.toString() ?? ''),
      orElse: () => null,
    );

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
        title: Text('iFutures - $symbol'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: symbol,
              dropdownColor: Colors.blueGrey.shade900,
              iconEnabledColor: Colors.white70,
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                if (value == null) return;
                ref.read(selectedSymbolProvider.notifier).state = value;
              },
              items: symbols
                  .map((s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(s),
                      ))
                  .toList(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'App Gallery',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GalleryScreen()),
              );
            },
          ),
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
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: PriceChart(symbol: symbol),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  OpenPositionCard(symbol: symbol, latestPrice: latestPrice),
                  const SizedBox(height: 16),
                  PerformanceMetrics(symbol: symbol),
                  const SizedBox(height: 16),
                  TradeHistory(symbol: symbol),
                ],
              ),
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
              'Market Insights - Live Monitoring',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
          if (isManual)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: !isRunning || engineAsync.isLoading
                        ? null
                        : () {
                            if (engineAsync is AsyncData<TradingEngine>) {
                              engineAsync.value.manualEnterLong();
                            }
                          },
                      child: const Text('LONG', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: !isRunning || engineAsync.isLoading
                        ? null
                        : () {
                            if (engineAsync is AsyncData<TradingEngine>) {
                              engineAsync.value.manualEnterShort();
                            }
                          },
                      child: const Text('SHORT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: !isRunning || engineAsync.isLoading
                        ? null
                        : () {
                            if (engineAsync is AsyncData<TradingEngine>) {
                              engineAsync.value.manualClose();
                            }
                          },
                      child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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
                      : () async {
                          if (engineAsync is AsyncData<TradingEngine>) {
                            final engine = engineAsync.value;
                            ref.read(isBotRunningProvider(symbol).notifier).state = true;
                            await engine.enableTrading();
                          }
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
                          if (engineAsync is AsyncData<TradingEngine>) {
                            final engine = engineAsync.value;
                            ref.read(isBotRunningProvider(symbol).notifier).state = false;
                            engine.disableTrading();
                          }
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
