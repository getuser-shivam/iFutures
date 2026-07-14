import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/binance_account_status.dart';
import '../../models/portfolio_analytics_snapshot.dart';
import '../../models/portfolio_symbol_breakdown.dart';
import '../../models/protection_status.dart';
import '../../models/trade.dart';
import '../../providers/trading_provider.dart';
import '../../services/portfolio_analytics_calculator.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';
import '../common/status_pill.dart';

class PortfolioAnalyticsCard extends ConsumerWidget {
  final String symbol;

  const PortfolioAnalyticsCard({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineAsync = ref.watch(tradingEngineProvider(symbol));
    final accountTradesAsync = ref.watch(accountTradeStreamProvider(symbol));
    final positionAsync = ref.watch(positionStreamProvider(symbol));
    final protectionAsync = ref.watch(protectionStatusProvider(symbol));
    final binanceStatusAsync = ref.watch(binanceAccountStatusProvider(symbol));

    final accountTrades = accountTradesAsync.maybeWhen(
      data: (data) => data,
      orElse: () => const <Trade>[],
    );
    final position = positionAsync.valueOrNull;
    final engine = engineAsync.valueOrNull;
    final protection = protectionAsync.maybeWhen(
      data: (status) => status,
      orElse: () => const ProtectionStatus.ready(),
    );
    final binanceStatus = binanceStatusAsync.valueOrNull;
    final tickerAsync = ref.watch(tickerStreamProvider(symbol));
    final latestPrice = tickerAsync.maybeWhen(
      data: (data) => double.tryParse(data['c']?.toString() ?? ''),
      orElse: () => null,
    );
    final snapshot = PortfolioAnalyticsCalculator.calculate(
      selectedSymbol: symbol,
      accountTrades: accountTrades,
      openPosition: position,
      latestPrice: latestPrice,
      walletBalance: engine?.walletBalance,
      availableBalance: engine?.availableBalance,
      openPositionCount: engine?.openPositionCount,
      latestPlan: engine?.lastDecisionPlan,
      recentTradeOutcomes: engine?.recentTradeOutcomes ?? const [],
    );

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 860;
              final title = const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Portfolio Analytics',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              final chips = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (binanceStatus != null)
                    StatusPill(
                      label: _accountLabel(binanceStatus),
                      color: _accountColor(binanceStatus.state),
                    ),
                  StatusPill(
                    label: _protectionLabel(protection),
                    color: _protectionColor(protection.state),
                  ),
                  StatusPill(
                    label:
                        'Tracked ${snapshot.trackedSymbolCount} symbol${snapshot.trackedSymbolCount == 1 ? '' : 's'}',
                    color: AppColors.glowCyan,
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), chips],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: chips,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Account balances, tracked fills, realized trade quality, and the latest AI posture in one view.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _CurrentPositionSnapshot(snapshot: snapshot, protection: protection),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1180
                  ? 4
                  : constraints.maxWidth > 720
                  ? 3
                  : 2;
              final spacing = 12.0;
              final tileWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              final metrics = [
                _PortfolioMetricTile(
                  label: 'Wallet',
                  value: _formatUsdt(snapshot.walletBalance),
                  helper: 'Total wallet balance',
                  accent: AppColors.glowCyan,
                ),
                _PortfolioMetricTile(
                  label: 'Available',
                  value: _formatUsdt(snapshot.availableBalance),
                  helper: 'Free margin',
                  accent: AppColors.positive,
                ),
                _PortfolioMetricTile(
                  label: 'Used Margin',
                  value: _formatUsdt(snapshot.usedMargin),
                  helper: 'Wallet - available',
                  accent: AppColors.glowAmber,
                ),
                _PortfolioMetricTile(
                  label: 'Margin Usage',
                  value: _formatPercent(snapshot.marginUsagePercent),
                  helper: 'Utilization',
                  accent: AppColors.glowAmber,
                ),
                _PortfolioMetricTile(
                  label: 'Open Markets',
                  value: snapshot.openPositionCount?.toString() ?? '--',
                  helper: 'Active tracked positions',
                  accent: AppColors.textPrimary,
                ),
                _PortfolioMetricTile(
                  label: 'Current Exposure',
                  value: _formatUsdt(snapshot.currentSymbolExposure),
                  helper: 'Selected symbol notional',
                  accent: AppColors.glowAmber,
                ),
                _PortfolioMetricTile(
                  label: 'Exposure Share',
                  value: _formatPercent(snapshot.exposureSharePercent),
                  helper: 'Selected symbol vs wallet',
                  accent: AppColors.glowAmber,
                ),
                _PortfolioMetricTile(
                  label: 'Realized PnL',
                  value: _formatSignedUsdt(snapshot.realizedSummary.totalPnL),
                  helper: snapshot.realizedSummary.totalTrades == 0
                      ? 'No closed fills'
                      : '${snapshot.realizedSummary.totalTrades} closed fills',
                  accent: snapshot.realizedSummary.totalPnL >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
                _PortfolioMetricTile(
                  label: 'Today PnL',
                  value: _formatSignedUsdt(snapshot.todaySummary.totalPnL),
                  helper: snapshot.todaySummary.totalTrades == 0
                      ? 'No closed fills today'
                      : '${snapshot.todaySummary.totalTrades} exits today',
                  accent: snapshot.todaySummary.totalPnL >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
                _PortfolioMetricTile(
                  label: 'Win Rate',
                  value: snapshot.realizedSummary.totalTrades == 0
                      ? '--'
                      : '${snapshot.realizedSummary.winRate.toStringAsFixed(0)}%',
                  helper: 'Tracked closed fills',
                  accent: snapshot.realizedSummary.winRate >= 50
                      ? AppColors.positive
                      : AppColors.warning,
                ),
                _PortfolioMetricTile(
                  label: 'PnL Drawdown',
                  value: snapshot.realizedSummary.totalTrades == 0
                      ? '--'
                      : '${snapshot.realizedSummary.maxDrawdown.toStringAsFixed(2)} USDT',
                  helper: 'Realized PnL peak to trough',
                  accent: AppColors.negative,
                ),
                _PortfolioMetricTile(
                  label: 'Outcome Bias',
                  value: snapshot.outcomeBias,
                  helper: 'Recent realized review',
                  accent: _outcomeBiasColor(snapshot.outcomeBias),
                ),
              ];

              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: [
                  for (final metric in metrics)
                    SizedBox(width: tileWidth, child: metric),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PortfolioInsight(
                title: 'AI Posture',
                accent: AppColors.glowCyan,
                lines: [
                  'Plan: ${snapshot.latestPlanLabel ?? 'No recent plan'}',
                  'Regime: ${snapshot.latestPlanMarketRegime ?? '--'}',
                  'Risk: ${snapshot.latestPlanRiskPosture ?? '--'}',
                  'Alignment: ${snapshot.latestPlanAlignment ?? '--'}',
                  'Execution: ${snapshot.latestPlanExecutionHint ?? '--'}',
                  'Memory: ${snapshot.latestPlanMemoryLabel ?? snapshot.outcomeBias}',
                ],
              ),
              _PortfolioInsight(
                title: 'Latest Outcome Review',
                accent: AppColors.glowAmber,
                lines: [
                  snapshot.latestOutcomeLine ??
                      'No realized exit is available yet. Once the account closes trades, this review starts tracking what just worked and what did not.',
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SymbolContributionSection(
            selectedSymbol: symbol,
            breakdowns: snapshot.symbolBreakdowns,
          ),
        ],
      ),
    );
  }

  static String _accountLabel(BinanceAccountStatus status) {
    final prefix = status.isTestnet ? 'Demo' : 'Live';
    return switch (status.state) {
      BinanceAccountState.notConfigured => 'Portfolio: Not Set',
      BinanceAccountState.checking => 'Portfolio: Checking',
      BinanceAccountState.active => 'Portfolio: $prefix',
      BinanceAccountState.limited => 'Portfolio: Read Only',
      BinanceAccountState.attentionRequired => 'Portfolio: Attention',
    };
  }

  static Color _accountColor(BinanceAccountState state) {
    return switch (state) {
      BinanceAccountState.notConfigured => AppColors.warning,
      BinanceAccountState.checking => AppColors.glowAmber,
      BinanceAccountState.active => AppColors.positive,
      BinanceAccountState.limited => AppColors.warning,
      BinanceAccountState.attentionRequired => AppColors.negative,
    };
  }

  static String _protectionLabel(ProtectionStatus status) {
    return switch (status.state) {
      ProtectionState.ready => 'Protection: Clear',
      ProtectionState.cooldown => 'Protection: Cooldown',
      ProtectionState.locked => 'Protection: Locked',
    };
  }

  static Color _protectionColor(ProtectionState state) {
    return switch (state) {
      ProtectionState.ready => AppColors.positive,
      ProtectionState.cooldown => AppColors.glowAmber,
      ProtectionState.locked => AppColors.warning,
    };
  }

  static Color _outcomeBiasColor(String bias) {
    final normalized = bias.toLowerCase();
    if (normalized.contains('pressing') ||
        normalized.contains('constructive')) {
      return AppColors.positive;
    }
    if (normalized.contains('cooling') ||
        normalized.contains('defensive') ||
        normalized.contains('cautious')) {
      return AppColors.warning;
    }
    if (normalized.contains('mixed')) {
      return AppColors.glowAmber;
    }
    return AppColors.textPrimary;
  }

  static String _formatUsdt(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    final digits = value >= 100
        ? 2
        : value >= 1
        ? 3
        : 6;
    return '${value.toStringAsFixed(digits)} USDT';
  }

  static String _formatSignedUsdt(double value) {
    if (value == 0) {
      return '0.00 USDT';
    }
    final prefix = value > 0 ? '+' : '-';
    final digits = value.abs() >= 100
        ? 2
        : value.abs() >= 1
        ? 3
        : 6;
    return '$prefix${value.abs().toStringAsFixed(digits)} USDT';
  }

  static String _formatPrice(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    final digits = value >= 100
        ? 2
        : value >= 1
        ? 4
        : 6;
    return value.toStringAsFixed(digits);
  }

  static String _formatQuantity(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    if (value >= 1000) {
      return value.toStringAsFixed(2);
    }
    if (value >= 1) {
      return value.toStringAsFixed(4);
    }
    return value.toStringAsFixed(6);
  }

  static String _formatPercent(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    return '${value.toStringAsFixed(1)}%';
  }
}

class _CurrentPositionSnapshot extends StatelessWidget {
  final PortfolioAnalyticsSnapshot snapshot;
  final ProtectionStatus protection;

  const _CurrentPositionSnapshot({
    required this.snapshot,
    required this.protection,
  });

  @override
  Widget build(BuildContext context) {
    final sideColor = switch (snapshot.currentPositionSideLabel) {
      'LONG' => AppColors.positive,
      'SHORT' => AppColors.negative,
      _ => AppColors.textSecondary,
    };
    final unrealized = snapshot.currentPositionUnrealizedPnl;
    final unrealizedColor = unrealized == null
        ? AppColors.textSecondary
        : (unrealized >= 0 ? AppColors.positive : AppColors.negative);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.stacked_line_chart,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Current Position Snapshot',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (snapshot.hasOpenPosition)
                StatusPill(
                  label: snapshot.currentPositionSideLabel!,
                  color: sideColor,
                )
              else
                const StatusPill(
                  label: 'No Position',
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.hasOpenPosition
                ? 'Live basics for ${snapshot.selectedSymbol}: side, entry, last price, size, exposure, and unrealized PnL.'
                : 'No live position is open on ${snapshot.selectedSymbol} right now. The account and trade review panels still stay in sync.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1080
                  ? 4
                  : constraints.maxWidth > 720
                  ? 3
                  : 2;
              final spacing = 12.0;
              final tileWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              final metrics = [
                _PortfolioMetricTile(
                  label: 'Symbol',
                  value: snapshot.selectedSymbol,
                  helper: 'Selected market',
                  accent: AppColors.glowCyan,
                ),
                _PortfolioMetricTile(
                  label: 'Entry',
                  value: PortfolioAnalyticsCard._formatPrice(
                    snapshot.currentPositionEntryPrice,
                  ),
                  helper: snapshot.currentPositionOpenedAt == null
                      ? 'No live entry'
                      : 'Opened ${_formatRelativeTime(snapshot.currentPositionOpenedAt)}',
                  accent: sideColor,
                ),
                _PortfolioMetricTile(
                  label: 'Last',
                  value: PortfolioAnalyticsCard._formatPrice(
                    snapshot.currentPositionLastPrice,
                  ),
                  helper: 'Latest ticker',
                  accent: AppColors.textPrimary,
                ),
                _PortfolioMetricTile(
                  label: 'Qty',
                  value: PortfolioAnalyticsCard._formatQuantity(
                    snapshot.currentPositionQuantity,
                  ),
                  helper: 'Live size',
                  accent: AppColors.glowAmber,
                ),
                _PortfolioMetricTile(
                  label: 'Exposure',
                  value: PortfolioAnalyticsCard._formatUsdt(
                    snapshot.currentSymbolExposure,
                  ),
                  helper: 'Entry x qty',
                  accent: AppColors.glowAmber,
                ),
                _PortfolioMetricTile(
                  label: 'Unrealized',
                  value: unrealized == null
                      ? '--'
                      : PortfolioAnalyticsCard._formatSignedUsdt(unrealized),
                  helper: snapshot.currentPositionUnrealizedPercent == null
                      ? 'Waiting for live price'
                      : 'Move ${snapshot.currentPositionUnrealizedPercent!.toStringAsFixed(2)}%',
                  accent: unrealizedColor,
                ),
                _PortfolioMetricTile(
                  label: 'Liquidation',
                  value: PortfolioAnalyticsCard._formatPrice(
                    snapshot.currentPositionLiquidationPrice,
                  ),
                  helper:
                      snapshot.currentPositionLiquidationDistancePercent == null
                      ? 'Waiting for synced liquidation'
                      : '${snapshot.currentPositionLiquidationDistancePercent!.toStringAsFixed(2)}% away',
                  accent: snapshot.currentPositionLiquidationPrice == null
                      ? AppColors.textSecondary
                      : AppColors.warning,
                ),
                _PortfolioMetricTile(
                  label: 'Protection',
                  value: PortfolioAnalyticsCard._protectionLabel(protection),
                  helper: 'Auto-entry guard state',
                  accent: PortfolioAnalyticsCard._protectionColor(
                    protection.state,
                  ),
                ),
                _PortfolioMetricTile(
                  label: 'Margin Share',
                  value: PortfolioAnalyticsCard._formatPercent(
                    snapshot.exposureSharePercent,
                  ),
                  helper: 'Selected symbol vs wallet',
                  accent: AppColors.glowAmber,
                ),
              ];

              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: [
                  for (final metric in metrics)
                    SizedBox(width: tileWidth, child: metric),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SymbolContributionSection extends StatelessWidget {
  final String selectedSymbol;
  final List<PortfolioSymbolBreakdown> breakdowns;

  const _SymbolContributionSection({
    required this.selectedSymbol,
    required this.breakdowns,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart_outline,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Tracked Symbol Contribution',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${breakdowns.length} symbol${breakdowns.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This breakdown keeps its own scroll. Live exposure is shown for $selectedSymbol when there is an active synced position.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (breakdowns.isEmpty)
            const Text(
              'Tracked symbols will appear here once Binance fills are synced.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          else
            SizedBox(
              height: (breakdowns.length * 118.0).clamp(150.0, 300.0),
              child: Scrollbar(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: breakdowns.length,
                  physics: const ClampingScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = breakdowns[index];
                    return _SymbolContributionTile(breakdown: item);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SymbolContributionTile extends StatelessWidget {
  final PortfolioSymbolBreakdown breakdown;

  const _SymbolContributionTile({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final pnlColor = breakdown.netPnl >= 0
        ? AppColors.positive
        : AppColors.negative;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: breakdown.isSelectedSymbol
              ? AppColors.glowCyan.withOpacity(0.45)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                breakdown.symbol,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              if (breakdown.isSelectedSymbol)
                const StatusPill(label: 'Selected', color: AppColors.glowCyan),
              if (breakdown.hasLiveExposure) ...[
                const SizedBox(width: 8),
                const StatusPill(
                  label: 'Live Exposure',
                  color: AppColors.glowAmber,
                ),
              ],
              const Spacer(),
              Text(
                _formatRelativeTime(breakdown.latestActivityAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _InlineMetric(
                label: 'Net PnL',
                value: PortfolioAnalyticsCard._formatSignedUsdt(
                  breakdown.netPnl,
                ),
                color: pnlColor,
              ),
              _InlineMetric(
                label: 'Win Rate',
                value: breakdown.closedTrades == 0
                    ? '--'
                    : '${breakdown.winRate.toStringAsFixed(0)}%',
              ),
              _InlineMetric(
                label: 'Closed Trades',
                value: breakdown.closedTrades.toString(),
              ),
              _InlineMetric(
                label: 'Fees',
                value: breakdown.totalFees <= 0
                    ? '--'
                    : PortfolioAnalyticsCard._formatUsdt(breakdown.totalFees),
              ),
              _InlineMetric(
                label: 'Exposure',
                value: breakdown.hasLiveExposure
                    ? PortfolioAnalyticsCard._formatUsdt(breakdown.liveExposure)
                    : '--',
                color: breakdown.hasLiveExposure
                    ? AppColors.glowAmber
                    : AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InlineMetric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRelativeTime(DateTime? timestamp) {
  if (timestamp == null) {
    return 'No activity';
  }
  return DateFormat('MMM d, HH:mm').format(timestamp.toLocal());
}

class _PortfolioMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color accent;

  const _PortfolioMetricTile({
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: tabularFigures(
              TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PortfolioInsight extends StatelessWidget {
  final String title;
  final Color accent;
  final List<String> lines;

  const _PortfolioInsight({
    required this.title,
    required this.accent,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final line in lines) ...[
                Text(
                  line,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                if (line != lines.last) const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}
