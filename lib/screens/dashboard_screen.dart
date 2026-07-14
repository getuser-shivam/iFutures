import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../constants/symbols.dart';
import '../models/ai_service_status.dart';
import '../models/binance_account_status.dart';
import '../models/strategy_mode.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/status_pill.dart';
import '../widgets/dashboard/market_analysis_card.dart';
import '../widgets/dashboard/daily_performance_card.dart';
import '../widgets/dashboard/ai_rule_bar.dart';
import '../widgets/dashboard/manual_order_ticket.dart';
import '../widgets/dashboard/open_position_card.dart';
import '../widgets/dashboard/order_book_execution_card.dart';
import '../widgets/dashboard/one_click_trade_card.dart';
import '../widgets/dashboard/price_alert_listener.dart';
import '../widgets/dashboard/price_alerts_card.dart';
import '../widgets/dashboard/price_chart.dart';
import '../widgets/dashboard/strategy_console_card.dart';
import '../widgets/dashboard/trade_history.dart';
import '../widgets/dashboard/performance_metrics.dart';
import '../widgets/dashboard/portfolio_analytics_card.dart';
import '../widgets/dashboard/risk_summary_card.dart';
import '../theme/app_theme.dart';
import '../trading/strategy.dart';
import 'settings_screen.dart';
import 'gallery_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(selectedSymbolProvider);
    final ticker = ref.watch(tickerStreamProvider(symbol));
    final settingsInit = ref.watch(settingsInitProvider);
    final binanceAccountStatus = ref.watch(
      binanceAccountStatusProvider(symbol),
    );
    final aiServiceStatus = ref.watch(aiServiceStatusProvider(symbol));
    final currentMode = ref.watch(currentStrategyModeProvider);
    final currentStrategy = ref.watch(currentStrategyProvider);
    final plan = ref.watch(decisionPlanStreamProvider(symbol)).valueOrNull;
    final isRunning = ref.watch(isBotRunningProvider(symbol));
    final openOrders =
        ref.watch(openOrderStreamProvider(symbol)).valueOrNull ?? const [];
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
                plan,
                isRunning,
                openOrders.length,
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
                    child: OneClickTradeCard(
                      key: ValueKey('one-click-$symbol'),
                      symbol: symbol,
                    ),
                  ),
                ),
                if (currentMode == StrategyMode.ai)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: AiRuleBar(symbol: symbol),
                    ),
                  ),
                if (currentMode == StrategyMode.manual)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: ManualOrderTicket(
                        key: ValueKey('manual-ticket-$symbol'),
                        symbol: symbol,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    currentMode == StrategyMode.manual ||
                            currentMode == StrategyMode.ai
                        ? 8
                        : 20,
                    20,
                    8,
                  ),
                  sliver: const SliverToBoxAdapter(child: RiskSummaryCard()),
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
                                  'Advanced live chart',
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
                            height: 420,
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
                    child: StrategyConsoleCard(symbol: symbol),
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
                  sliver: SliverToBoxAdapter(
                    child: OrderBookExecutionCard(symbol: symbol),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: PortfolioAnalyticsCard(symbol: symbol),
                  ),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  sliver: const SliverToBoxAdapter(child: SizedBox(height: 4)),
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
    StrategyTradePlan? plan,
    bool isRunning,
    int openOrderCount,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SymbolDropdown(
          value: symbol,
          symbols: symbols,
          onChanged: (value) async {
            if (value == null || value == symbol) return;
            final disarm = await ref
                .read(tradingRuntimeSafetyProvider)
                .disarmBeforeRuntimeChange(
                  symbol: symbol,
                  reason: 'symbol_switch',
                );
            if (!disarm.canProceed) {
              ref.read(isBotRunningProvider(symbol).notifier).state = false;
              if (context.mounted) {
                showAppToast(
                  context,
                  'Symbol switch blocked: working $symbol entries could not be confirmed cancelled. Check Binance orders and retry. (${disarm.error})',
                  backgroundColor: AppColors.negative.withValues(alpha: 0.95),
                  foregroundColor: Colors.white,
                  icon: Icons.gpp_bad_outlined,
                  duration: const Duration(seconds: 5),
                );
              }
              return;
            }
            ref.read(isBotRunningProvider(symbol).notifier).state = false;
            try {
              await ref.read(selectedSymbolProvider.notifier).setSymbol(value);
            } catch (error) {
              try {
                await ref
                    .read(selectedSymbolProvider.notifier)
                    .setSymbol(symbol);
              } catch (_) {
                // The in-memory selection is still restored by setSymbol.
              }
              if (context.mounted) {
                showAppToast(
                  context,
                  'The symbol was not changed because it could not be saved: $error',
                  backgroundColor: AppColors.negative.withValues(alpha: 0.95),
                  foregroundColor: Colors.white,
                  icon: Icons.error_outline,
                );
              }
            }
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
            StatusPill(
              label: _tradingHeaderLabel(
                currentMode: currentMode,
                isRunning: isRunning,
                plan: plan,
                openOrderCount: openOrderCount,
              ),
              color: _tradingHeaderColor(
                currentMode: currentMode,
                isRunning: isRunning,
                plan: plan,
                openOrderCount: openOrderCount,
              ),
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

  Widget _buildBinanceBadge(
    AsyncValue<BinanceAccountStatus> status, {
    bool compact = false,
  }) {
    return status.when(
      data: (data) {
        final prefix = data.isTestnet ? 'Binance Demo' : 'Binance Live';
        return switch (data.state) {
          BinanceAccountState.notConfigured => StatusPill(
            label: '$prefix: Not Configured',
            color: AppColors.warning,
          ),
          BinanceAccountState.checking => StatusPill(
            label: '$prefix: Checking',
            color: AppColors.glowAmber,
          ),
          BinanceAccountState.active => StatusPill(
            label: data.isTestnet
                ? 'Binance Demo: Active'
                : 'Binance Live: REAL MONEY',
            color: data.isTestnet ? AppColors.glowAmber : AppColors.negative,
          ),
          BinanceAccountState.limited => StatusPill(
            label: '$prefix: Read Only',
            color: AppColors.warning,
          ),
          BinanceAccountState.attentionRequired => StatusPill(
            label: '$prefix: Attention',
            color: AppColors.negative,
          ),
        };
      },
      loading: () => StatusPill(
        label: compact ? 'Binance: Checking' : 'Binance: Checking',
        color: AppColors.glowAmber,
      ),
      error: (e, _) =>
          const StatusPill(label: 'Binance: Error', color: AppColors.negative),
    );
  }

  static Color _modeColor(StrategyMode mode) {
    return switch (mode) {
      StrategyMode.manual => AppColors.glowAmber,
      StrategyMode.algo => AppColors.positive,
      StrategyMode.ai => AppColors.glowCyan,
    };
  }

  static String _tradingHeaderLabel({
    required StrategyMode currentMode,
    required bool isRunning,
    required StrategyTradePlan? plan,
    required int openOrderCount,
  }) {
    if (currentMode == StrategyMode.manual) {
      return 'Trading: Manual';
    }
    if (!isRunning) {
      return 'Trading: Auto Off';
    }
    if (openOrderCount > 0) {
      return 'Trading: $openOrderCount Working';
    }
    if (plan == null || plan.signal == TradingSignal.hold) {
      return 'Trading: Waiting';
    }
    return 'Trading: ${plan.actionLabel} ${plan.orderTypeLabel}';
  }

  static Color _tradingHeaderColor({
    required StrategyMode currentMode,
    required bool isRunning,
    required StrategyTradePlan? plan,
    required int openOrderCount,
  }) {
    if (currentMode == StrategyMode.manual) {
      return AppColors.glowAmber;
    }
    if (!isRunning) {
      return AppColors.warning;
    }
    if (openOrderCount > 0) {
      return AppColors.glowCyan;
    }
    if (plan == null || plan.signal == TradingSignal.hold) {
      return AppColors.textSecondary;
    }
    return switch (plan.orderTypeLabel.toLowerCase()) {
      'market' => AppColors.negative,
      'limit' => AppColors.glowCyan,
      'post only' => AppColors.positive,
      'scaled' => AppColors.glowAmber,
      _ => AppColors.glowCyan,
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
