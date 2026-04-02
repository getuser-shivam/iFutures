import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../trading/trading_engine.dart';
import '../constants/symbols.dart';
import '../models/ai_service_status.dart';
import '../models/binance_account_status.dart';
import '../models/connection_status.dart';
import '../models/strategy_mode.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/action_button.dart';
import '../widgets/common/status_pill.dart';
import '../widgets/dashboard/market_analysis_card.dart';
import '../widgets/dashboard/daily_performance_card.dart';
import '../widgets/dashboard/open_position_card.dart';
import '../widgets/dashboard/price_alert_listener.dart';
import '../widgets/dashboard/price_alerts_card.dart';
import '../widgets/dashboard/price_chart.dart';
import '../widgets/dashboard/strategy_console_card.dart';
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
    final settingsInit = ref.watch(settingsInitProvider);
    final connectionStatus = ref.watch(connectionStatusProvider(symbol));
    final binanceAccountStatus = ref.watch(
      binanceAccountStatusProvider(symbol),
    );
    final aiServiceStatus = ref.watch(aiServiceStatusProvider(symbol));
    final currentMode = ref.watch(currentStrategyModeProvider);
    final currentStrategy = ref.watch(currentStrategyProvider);
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(82),
        child: Material(
          color: AppColors.backgroundTop,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
              child: _buildTopBar(
                context,
                ref,
                ticker,
                symbol,
                symbols,
                aiServiceStatus,
                binanceAccountStatus,
                currentMode,
                currentStrategy?.name,
              ),
            ),
          ),
        ),
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
                    child: _buildStrategyWorkspaceHint(
                      context,
                      currentMode,
                      currentStrategy?.name,
                      symbol,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: StrategyConsoleCard(symbol: symbol),
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
                    child: MarketAnalysisCard(symbol: symbol),
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
                    child: PriceAlertsCard(symbol: symbol),
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
                    child: _buildStatusRow(
                      isRunning,
                      engineAsync,
                      connectionStatus,
                      aiServiceStatus,
                      binanceAccountStatus,
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

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> ticker,
    String symbol,
    List<String> symbols,
    AsyncValue<AiServiceStatus> aiServiceStatus,
    AsyncValue<BinanceAccountStatus> binanceAccountStatus,
    StrategyMode currentMode,
    String? strategyName,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SymbolDropdown(
          value: symbol,
          symbols: symbols,
          onChanged: (value) {
            if (value == null) return;
            ref.read(selectedSymbolProvider.notifier).setSymbol(value);
          },
        ),
        const SizedBox(width: 8),
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
          tooltip: 'Settings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;

        final leftContent = ticker.when(
          data: (data) {
            final dynamic priceValue = data is Map ? data['c'] : data;
            final priceText = priceValue?.toString() ?? '--';
            return Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Text(
                  priceText,
                  style: tabularFigures(
                    const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  'USDT',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.35,
                  ),
                ),
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
                Text(
                  symbol,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (e, s) => Text(
            'Error: $e',
            style: const TextStyle(color: AppColors.negative),
          ),
        );

        final rightContent = Wrap(
          alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: 'Mode: ${currentMode.label}',
              color: _modeColor(currentMode),
            ),
            _buildBinanceBadge(binanceAccountStatus, compact: true),
            if (strategyName != null && strategyName.trim().isNotEmpty)
              Text(
                _strategyHeaderLabel(
                  strategyName,
                  currentMode,
                  aiServiceStatus,
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: leftContent),
                  const SizedBox(width: 12),
                  actions,
                ],
              ),
              const SizedBox(height: 8),
              rightContent,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 5, child: leftContent),
            const SizedBox(width: 18),
            Expanded(flex: 4, child: rightContent),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }

  String _strategyHeaderLabel(
    String strategyName,
    StrategyMode currentMode,
    AsyncValue<AiServiceStatus> aiServiceStatus,
  ) {
    if (currentMode != StrategyMode.ai) {
      return strategyName;
    }

    final suffix = aiServiceStatus.when(
      data: (data) => switch (data.state) {
        AiServiceState.notConfigured => 'Not Set',
        AiServiceState.checking => 'Checking',
        AiServiceState.active => 'Active',
        AiServiceState.attentionRequired => 'Attention',
      },
      loading: () => 'Checking',
      error: (_, __) => 'Error',
    );

    return '$strategyName: $suffix';
  }

  Widget _buildStrategyWorkspaceHint(
    BuildContext context,
    StrategyMode currentMode,
    String? strategyName,
    String symbol,
  ) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, color: AppColors.textSecondary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Strategy Workspace',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('OPEN SETTINGS'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.glowCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Mode selection, manual tickets, and backtesting now live in Settings. The dashboard keeps the live strategy terminal visible for monitoring and troubleshooting.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: 'Active: ${currentMode.label}',
                color: _modeColor(currentMode),
              ),
              if (strategyName != null && strategyName.trim().isNotEmpty)
                StatusPill(label: strategyName, color: AppColors.glowCyan),
              StatusPill(label: 'Symbol: $symbol', color: AppColors.glowAmber),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _dashboardHintForMode(currentMode),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
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
    AsyncValue<AiServiceStatus> aiServiceStatus,
    AsyncValue<BinanceAccountStatus> binanceAccountStatus,
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
        _buildAiBadge(aiServiceStatus),
        _buildBinanceBadge(binanceAccountStatus),
        _buildConnectionBadge(connectionStatus),
      ],
    );
  }

  Widget _buildAiBadge(
    AsyncValue<AiServiceStatus> status, {
    bool compact = false,
  }) {
    return status.when(
      data: (data) {
        return switch (data.state) {
          AiServiceState.notConfigured => StatusPill(
            label: compact ? 'AI API: Not Set' : 'AI API: Not Configured',
            color: AppColors.warning,
          ),
          AiServiceState.checking => StatusPill(
            label: compact ? 'AI API: Checking' : 'AI API: Checking',
            color: AppColors.glowAmber,
          ),
          AiServiceState.active => StatusPill(
            label: compact ? 'AI API: Active' : 'AI API: Active',
            color: AppColors.positive,
          ),
          AiServiceState.attentionRequired => StatusPill(
            label: compact ? 'AI API: Attention' : 'AI API: Attention',
            color: AppColors.negative,
          ),
        };
      },
      loading: () => const StatusPill(
        label: 'AI API: Checking',
        color: AppColors.glowAmber,
      ),
      error: (e, _) =>
          const StatusPill(label: 'AI API: Error', color: AppColors.negative),
    );
  }

  Widget _buildBinanceBadge(
    AsyncValue<BinanceAccountStatus> status, {
    bool compact = false,
  }) {
    return status.when(
      data: (data) {
        final prefix = data.isTestnet ? 'Binance Demo' : 'Binance Live';
        return switch (data.state) {
          BinanceAccountState.notConfigured => StatusPill(
            label: compact ? 'Binance: Not Set' : '$prefix: Not Configured',
            color: AppColors.warning,
          ),
          BinanceAccountState.checking => StatusPill(
            label: compact ? 'Binance: Checking' : '$prefix: Checking',
            color: AppColors.glowAmber,
          ),
          BinanceAccountState.active => StatusPill(
            label: compact ? 'Binance: Active' : '$prefix: Active',
            color: AppColors.positive,
          ),
          BinanceAccountState.limited => StatusPill(
            label: compact ? 'Binance: Read Only' : '$prefix: Read Only',
            color: AppColors.warning,
          ),
          BinanceAccountState.attentionRequired => StatusPill(
            label: compact ? 'Binance: Attention' : '$prefix: Attention',
            color: AppColors.negative,
          ),
        };
      },
      loading: () => StatusPill(
        label: compact ? 'Binance: Checking' : 'Binance: Checking',
        color: AppColors.glowAmber,
      ),
      error: (e, _) =>
          StatusPill(label: 'Binance: Error', color: AppColors.negative),
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

  static Color _modeColor(StrategyMode mode) {
    return switch (mode) {
      StrategyMode.manual => AppColors.glowAmber,
      StrategyMode.algo => AppColors.positive,
      StrategyMode.ai => AppColors.glowCyan,
    };
  }

  static String _dashboardHintForMode(StrategyMode mode) {
    return switch (mode) {
      StrategyMode.manual =>
        'Manual order controls are available from Settings > Strategy Workspace. The dashboard keeps the live terminal visible so market and account activity are easy to monitor.',
      StrategyMode.algo =>
        'RSI tuning and backtests are grouped in Settings > Strategy Workspace, while the live terminal stays here for monitoring.',
      StrategyMode.ai =>
        'AI provider settings and trade zones are grouped in Settings > Strategy Workspace, while the live terminal stays here for monitoring.',
    };
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
