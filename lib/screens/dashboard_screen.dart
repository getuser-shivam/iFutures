import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../trading/trading_engine.dart';
import '../trading/manual_strategy.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/dashboard/mode_selector.dart';
import '../widgets/dashboard/open_position_card.dart';
import '../widgets/dashboard/price_chart.dart';
import '../widgets/dashboard/trade_history.dart';
import '../widgets/dashboard/performance_metrics.dart';
import '../widgets/dashboard/risk_summary_card.dart';
import '../theme/app_theme.dart';
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
        title: const Text('iFutures'),
        actions: [
          _SymbolDropdown(
            value: symbol,
            symbols: symbols,
            onChanged: (value) {
              if (value == null) return;
              ref.read(selectedSymbolProvider.notifier).state = value;
            },
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'App Gallery',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GalleryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            const _DashboardBackdrop(),
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: _buildHeader(context, ticker, symbol),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.candlestick_chart, color: AppColors.textSecondary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Price Action',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Text(
                                  'Last 50 candles',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 260,
                            child: PriceChart(symbol: symbol),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: OpenPositionCard(symbol: symbol, latestPrice: latestPrice),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: RiskSummaryCard(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: PerformanceMetrics(symbol: symbol),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: TradeHistory(symbol: symbol),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: _buildStatusRow(isRunning, engineAsync),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Market Insights - Live Monitoring',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (isManual)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: AppPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manual Controls',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    label: 'LONG',
                                    icon: Icons.arrow_upward,
                                    color: AppColors.positive,
                                    onPressed: !isRunning || engineAsync.isLoading
                                        ? null
                                        : () {
                                            if (engineAsync is AsyncData<TradingEngine>) {
                                              engineAsync.value.manualEnterLong();
                                            }
                                          },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionButton(
                                    label: 'SHORT',
                                    icon: Icons.arrow_downward,
                                    color: AppColors.negative,
                                    onPressed: !isRunning || engineAsync.isLoading
                                        ? null
                                        : () {
                                            if (engineAsync is AsyncData<TradingEngine>) {
                                              engineAsync.value.manualEnterShort();
                                            }
                                          },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionButton(
                                    label: 'CLOSE',
                                    icon: Icons.close,
                                    color: AppColors.textSecondary,
                                    onPressed: !isRunning || engineAsync.isLoading
                                        ? null
                                        : () {
                                            if (engineAsync is AsyncData<TradingEngine>) {
                                              engineAsync.value.manualClose();
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: AppPanel(
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'START BOT',
                              icon: Icons.play_arrow,
                              color: AppColors.positive,
                              onPressed: isRunning || engineAsync.isLoading
                                  ? null
                                  : () async {
                                      if (engineAsync is AsyncData<TradingEngine>) {
                                        final engine = engineAsync.value;
                                        ref.read(isBotRunningProvider(symbol).notifier).state = true;
                                        await engine.enableTrading();
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ActionButton(
                              label: 'STOP BOT',
                              icon: Icons.stop_circle_outlined,
                              color: AppColors.negative,
                              onPressed: !isRunning || engineAsync.isLoading
                                  ? null
                                  : () {
                                      if (engineAsync is AsyncData<TradingEngine>) {
                                        final engine = engineAsync.value;
                                        ref.read(isBotRunningProvider(symbol).notifier).state = false;
                                        engine.disableTrading();
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<dynamic> ticker, String symbol) {
    final textTheme = Theme.of(context).textTheme;

    return AppPanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Price',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              ticker.when(
                data: (data) {
                  final dynamic priceValue = data is Map ? data['c'] : data;
                  final priceText = priceValue?.toString() ?? '--';
                  return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceText,
                      style: tabularFigures(
                        const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'USDT',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.glowCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                );
                },
                loading: () => const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, s) => Text('Error: $e', style: const TextStyle(color: AppColors.negative)),
              ),
              const SizedBox(height: 8),
              Text(
                symbol,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const ModeSelector(),
        ],
      ),
    );
  }

  Widget _buildStatusRow(bool isRunning, AsyncValue<TradingEngine> engineAsync) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatusPill(
          label: isRunning ? 'Bot: Running' : 'Bot: Stopped',
          color: isRunning ? AppColors.positive : AppColors.negative,
        ),
        engineAsync.when(
          data: (_) => const _StatusPill(
            label: 'Engine: Ready',
            color: AppColors.positive,
          ),
          loading: () => const _StatusPill(
            label: 'Engine: Loading...',
            color: AppColors.warning,
          ),
          error: (e, _) => const _StatusPill(
            label: 'Engine: Error',
            color: AppColors.negative,
          ),
        ),
      ],
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppColors.glowCyan.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          left: -120,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppColors.glowAmber.withOpacity(0.16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SymbolDropdown extends StatelessWidget {
  final String value;
  final List<String> symbols;
  final ValueChanged<String?> onChanged;

  const _SymbolDropdown({
    required this.value,
    required this.symbols,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surface,
          iconEnabledColor: AppColors.textSecondary,
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: onChanged,
          items: symbols
              .map((s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(s),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.95),
                  color.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
