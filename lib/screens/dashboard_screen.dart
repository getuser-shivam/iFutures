import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../trading/trading_engine.dart';
import '../trading/algo_strategy.dart';
import '../trading/strategy.dart';
import '../constants/symbols.dart';
import '../models/connection_status.dart';
import '../models/rsi_strategy_preset.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/action_button.dart';
import '../widgets/common/status_pill.dart';
import '../widgets/dashboard/mode_selector.dart';
import '../widgets/dashboard/market_analysis_card.dart';
import '../widgets/dashboard/daily_performance_card.dart';
import '../widgets/dashboard/backtest_card.dart';
import '../widgets/dashboard/open_position_card.dart';
import '../widgets/dashboard/price_alert_listener.dart';
import '../widgets/dashboard/price_alerts_card.dart';
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
    final settingsInit = ref.watch(settingsInitProvider);
    final connectionStatus = ref.watch(connectionStatusProvider(symbol));
    final signalAsync = ref.watch(signalStreamProvider(symbol));
    final symbolsAsync = ref.watch(symbolListProvider);
    final symbols = symbolsAsync.maybeWhen(
      data: (data) => data,
      orElse: () => defaultSymbols,
    );
    final latestPrice = ticker.maybeWhen(
      data: (data) => double.tryParse(data['c']?.toString() ?? ''),
      orElse: () => null,
    );
    if (symbols.isNotEmpty && !symbols.contains(symbol)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedSymbolProvider.notifier).setSymbol(symbols.first);
      });
    }

    if (settingsInit.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
              ref.read(selectedSymbolProvider.notifier).setSymbol(value);
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
            PriceAlertListener(symbol: symbol),
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
                    child: MarketAnalysisCard(symbol: symbol),
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
                              const Icon(
                                Icons.candlestick_chart,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Text(
                                  'Last 50 candles',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
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
                    child: OpenPositionCard(
                      symbol: symbol,
                      latestPrice: latestPrice,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(child: RiskSummaryCard()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: DailyPerformanceCard(symbol: symbol),
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
                    child: BacktestCard(symbol: symbol),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: PriceAlertsCard(symbol: symbol),
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
                    child: _buildStatusRow(
                      isRunning,
                      engineAsync,
                      connectionStatus,
                    ),
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
                          const SizedBox(height: 6),
                          Text(
                            'Manual actions stay available in every mode. If AI or the selected algorithm opens the position, LONG, SHORT, and CLOSE stay available so you can take over instantly.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildSignalPill(signalAsync),
                              if (currentStrategy != null)
                                StatusPill(
                                  label:
                                      'Source: ${_strategyLabel(currentStrategy, ref)}',
                                  color: AppColors.glowCyan,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ActionButton(
                                  label: 'LONG',
                                  icon: Icons.arrow_upward,
                                  color: AppColors.positive,
                                  onPressed: engineAsync.isLoading
                                      ? null
                                      : () async {
                                          if (engineAsync
                                              is AsyncData<TradingEngine>) {
                                            final engine = engineAsync.value;
                                            await _ensureMarketData(engine);
                                            await engine.manualEnterLong();
                                          }
                                        },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ActionButton(
                                  label: 'SHORT',
                                  icon: Icons.arrow_downward,
                                  color: AppColors.negative,
                                  onPressed: engineAsync.isLoading
                                      ? null
                                      : () async {
                                          if (engineAsync
                                              is AsyncData<TradingEngine>) {
                                            final engine = engineAsync.value;
                                            await _ensureMarketData(engine);
                                            await engine.manualEnterShort();
                                          }
                                        },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ActionButton(
                                  label: 'CLOSE',
                                  icon: Icons.close,
                                  color: AppColors.textSecondary,
                                  onPressed: engineAsync.isLoading
                                      ? null
                                      : () async {
                                          if (engineAsync
                                              is AsyncData<TradingEngine>) {
                                            final engine = engineAsync.value;
                                            await _ensureMarketData(engine);
                                            await engine.manualClose();
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
                            child: ActionButton(
                              label: 'START BOT',
                              icon: Icons.play_arrow,
                              color: AppColors.positive,
                              onPressed: isRunning || engineAsync.isLoading
                                  ? null
                                  : () async {
                                      if (engineAsync
                                          is AsyncData<TradingEngine>) {
                                        final engine = engineAsync.value;
                                        ref
                                                .read(
                                                  isBotRunningProvider(
                                                    symbol,
                                                  ).notifier,
                                                )
                                                .state =
                                            true;
                                        await engine.enableTrading();
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ActionButton(
                              label: 'STOP BOT',
                              icon: Icons.stop_circle_outlined,
                              color: AppColors.negative,
                              onPressed: !isRunning || engineAsync.isLoading
                                  ? null
                                  : () {
                                      if (engineAsync
                                          is AsyncData<TradingEngine>) {
                                        final engine = engineAsync.value;
                                        ref
                                                .read(
                                                  isBotRunningProvider(
                                                    symbol,
                                                  ).notifier,
                                                )
                                                .state =
                                            false;
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

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<dynamic> ticker,
    String symbol,
  ) {
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
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
                error: (e, s) => Text(
                  'Error: $e',
                  style: const TextStyle(color: AppColors.negative),
                ),
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

  Future<void> _ensureMarketData(TradingEngine engine) async {
    if (!engine.isStreaming) {
      await engine.startMarketData();
    }
  }

  Widget _buildSignalPill(AsyncValue<TradingSignal?> signalAsync) {
    return signalAsync.when(
      data: (signal) {
        final label = _signalLabel(signal);
        final color = _signalColor(signal);
        return StatusPill(label: 'Signal: $label', color: color);
      },
      loading: () => const StatusPill(
        label: 'Signal: ...',
        color: AppColors.textSecondary,
      ),
      error: (_, __) =>
          const StatusPill(label: 'Signal: Error', color: AppColors.warning),
    );
  }

  String _signalLabel(TradingSignal? signal) {
    switch (signal) {
      case TradingSignal.buy:
        return 'BUY';
      case TradingSignal.sell:
        return 'SELL';
      case TradingSignal.hold:
        return 'HOLD';
      default:
        return '--';
    }
  }

  String _strategyLabel(TradingStrategy? strategy, WidgetRef ref) {
    if (strategy is RsiStrategy) {
      final settings = ref.read(settingsServiceProvider);
      final preset = findRsiStrategyPreset(
        period: settings.getRsiPeriod(),
        overbought: settings.getRsiOverbought(),
        oversold: settings.getRsiOversold(),
      );

      if (preset != null) {
        return '${strategy.name} (${preset.label})';
      }

      return '${strategy.name} (Custom)';
    }

    return strategy?.name ?? '--';
  }

  Color _signalColor(TradingSignal? signal) {
    switch (signal) {
      case TradingSignal.buy:
        return AppColors.positive;
      case TradingSignal.sell:
        return AppColors.negative;
      case TradingSignal.hold:
        return AppColors.textSecondary;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatRetryDelay(int delayMs) {
    if (delayMs < 1000) {
      return '${delayMs}ms';
    }

    final seconds = (delayMs / 1000).ceil();
    if (seconds < 60) {
      return '${seconds}s';
    }

    final minutes = (seconds / 60).ceil();
    return '${minutes}m';
  }

  Widget _buildStatusRow(
    bool isRunning,
    AsyncValue<TradingEngine> engineAsync,
    AsyncValue<ConnectionStatus> connectionStatus,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        StatusPill(
          label: isRunning ? 'Bot: Running' : 'Bot: Stopped',
          color: isRunning ? AppColors.positive : AppColors.negative,
        ),
        engineAsync.when(
          data: (_) => const StatusPill(
            label: 'Engine: Ready',
            color: AppColors.positive,
          ),
          loading: () => const StatusPill(
            label: 'Engine: Loading...',
            color: AppColors.warning,
          ),
          error: (e, _) => const StatusPill(
            label: 'Engine: Error',
            color: AppColors.negative,
          ),
        ),
        _buildConnectionBadge(connectionStatus),
      ],
    );
  }

  Widget _buildConnectionBadge(AsyncValue<ConnectionStatus> status) {
    return status.when(
      data: (data) {
        final ageSeconds = data.lastMessageAt == null
            ? null
            : DateTime.now().difference(data.lastMessageAt!).inSeconds;
        final latency = data.latencyMs != null ? '${data.latencyMs}ms' : '--';

        switch (data.state) {
          case MarketConnectionState.connecting:
            return const StatusPill(
              label: 'Market: Connecting',
              color: AppColors.glowAmber,
            );
          case MarketConnectionState.connected:
            return StatusPill(
              label: 'Market: Live | $latency',
              color: AppColors.glowCyan,
            );
          case MarketConnectionState.stale:
            return StatusPill(
              label: 'Market: Slow | ${ageSeconds ?? '-'}s',
              color: AppColors.warning,
            );
          case MarketConnectionState.reconnecting:
            final delay = data.retryDelayMs == null
                ? null
                : _formatRetryDelay(data.retryDelayMs!);
            final attempt = data.retryAttempt ?? 1;
            final suffix = delay == null ? '' : ' in $delay';
            return StatusPill(
              label: 'Market: Reconnecting #$attempt$suffix',
              color: AppColors.warning,
            );
          case MarketConnectionState.disconnected:
            return const StatusPill(
              label: 'Market: Offline',
              color: AppColors.negative,
            );
        }
      },
      loading: () => const StatusPill(
        label: 'Market: Connecting',
        color: AppColors.glowAmber,
      ),
      error: (e, _) =>
          const StatusPill(label: 'Market: Error', color: AppColors.negative),
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
                  AppColors.glowCyan.withValues(alpha: 0.18),
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
                  AppColors.glowAmber.withValues(alpha: 0.16),
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
              .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
              .toList(),
        ),
      ),
    );
  }
}
